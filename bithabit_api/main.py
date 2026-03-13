"""
BitHabit API server
- Email OTP login (no password)
- Chat messages with GIF support
- WebSocket real-time chat
"""
import os
import json
import uuid
import base64
import random
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from typing import List, Optional
from contextlib import asynccontextmanager

from fastapi import APIRouter, FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import engine, get_db, Base
from models import User, Message

# .env 로드
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Gmail 설정
GMAIL_ADDRESS = os.environ.get("GMAIL_ADDRESS", "")
GMAIL_APP_PASSWORD = os.environ.get("GMAIL_APP_PASSWORD", "").replace(" ", "")

# JWT 설정
JWT_SECRET = os.environ.get("JWT_SECRET", "bithabit-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 7   # 자동 로그인 유지 7일
REFRESH_TOKEN_EXPIRE_DAYS = 30  # 리프레시 토큰 30일

# Bearer 토큰 스키마
bearer_scheme = HTTPBearer(auto_error=False)


# 앱 시작 시 테이블 생성
@asynccontextmanager
async def lifespan(app: FastAPI):
    """앱 시작/종료 시 실행되는 이벤트"""
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="BitHabit API",
    description="BitHabit 채팅 및 GIF 공유 API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 정적 파일 서빙 (업로드된 GIF, 환경변수 또는 기본값)
UPLOAD_DIR = os.environ.get("UPLOAD_DIR", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


# ============ Pydantic 스키마 ============

class UserRegister(BaseModel):
    """회원가입 요청 (닉네임 + 이메일)"""
    username: str
    email: str


class SendOtpRequest(BaseModel):
    """OTP 발송 요청"""
    email: str


class VerifyOtpRequest(BaseModel):
    """OTP 검증 요청"""
    email: str
    otp: str


class UserResponse(BaseModel):
    """사용자 응답"""
    id: int
    username: str
    email: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """로그인 응답 (유저 정보 + JWT 토큰)"""
    user: UserResponse
    access_token: str
    refresh_token: str


class RefreshRequest(BaseModel):
    """토큰 갱신 요청"""
    refresh_token: str


class MessageCreate(BaseModel):
    """메시지 생성 (텍스트만)"""
    text: Optional[str] = None


class MessageResponse(BaseModel):
    """메시지 응답"""
    id: int
    user_id: int
    username: str
    gif_path: Optional[str]
    gif_url: Optional[str]
    text: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============ WebSocket 관리 ============

class ConnectionManager:
    """WebSocket 연결 관리자"""
    
    def __init__(self):
        self.active_connections: List[WebSocket] = []
    
    async def connect(self, websocket: WebSocket):
        """새 연결 수락"""
        await websocket.accept()
        self.active_connections.append(websocket)
    
    def disconnect(self, websocket: WebSocket):
        """연결 해제"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
    
    async def broadcast(self, message: dict):
        """모든 연결에 메시지 전송"""
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except:
                pass


manager = ConnectionManager()

# /api prefix 라우터
api_router = APIRouter(prefix="/api")


# ============ JWT 유틸 ============

def create_access_token(user_id: int, username: str) -> str:
    """Access token 생성 (7일 유효)"""
    expire = datetime.utcnow() + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    payload = {"sub": str(user_id), "username": username, "exp": expire, "type": "access"}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_refresh_token(user_id: int) -> str:
    """Refresh token 생성 (30일 유효)"""
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": str(user_id), "exp": expire, "type": "refresh"}
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_token(token: str) -> dict:
    """토큰 검증 후 payload 반환, 실패 시 None"""
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError:
        return None


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Authorization 헤더에서 JWT 추출 → 유저 반환"""
    if not creds:
        raise HTTPException(status_code=401, detail="인증이 필요합니다")
    payload = verify_token(creds.credentials)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="토큰이 만료되었거나 유효하지 않습니다")
    user = db.query(User).filter(User.id == int(payload["sub"])).first()
    if not user:
        raise HTTPException(status_code=401, detail="존재하지 않는 사용자입니다")
    return user


# ============ 이메일 유틸 ============

def generate_otp() -> str:
    """6자리 숫자 OTP 생성"""
    return str(random.randint(100000, 999999))


def send_otp_email(to_email: str, otp: str, username: str) -> None:
    """Gmail SMTP로 OTP 발송"""
    body = f"""안녕하세요, {username}님!

BitHabit 로그인 인증 코드입니다.

━━━━━━━━━━━━━━━
  인증 코드:  {otp}
━━━━━━━━━━━━━━━

이 코드는 5분간 유효합니다.
본인이 요청하지 않았다면 무시하세요.

— BitHabit 팀
"""
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = f"[BitHabit] 로그인 인증 코드: {otp}"
    msg["From"] = GMAIL_ADDRESS
    msg["To"] = to_email

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
        smtp.login(GMAIL_ADDRESS, GMAIL_APP_PASSWORD)
        smtp.send_message(msg)


# ============ 인증 API ============

@api_router.post("/auth/register", response_model=UserResponse)
def register(body: UserRegister, db: Session = Depends(get_db)):
    """
    회원가입 API — 닉네임 + 이메일만 받음 (비밀번호 없음)

    Args:
        body: username, email
        db: 데이터베이스 세션

    Returns:
        생성된 사용자 정보
    """
    if db.query(User).filter(User.username == body.username).first():
        raise HTTPException(status_code=400, detail="이미 사용 중인 닉네임입니다")
    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(status_code=400, detail="이미 가입된 이메일입니다")

    db_user = User(username=body.username, email=body.email)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@api_router.post("/auth/send-otp")
def send_otp(body: SendOtpRequest, db: Session = Depends(get_db)):
    """
    OTP 발송 API — 이메일로 6자리 코드 전송

    Args:
        body: email
        db: 데이터베이스 세션

    Returns:
        성공 메시지
    """
    db_user = db.query(User).filter(User.email == body.email).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="가입되지 않은 이메일입니다")

    otp = generate_otp()
    db_user.otp_code = otp
    db_user.otp_expires_at = datetime.utcnow() + timedelta(minutes=5)
    db.commit()

    try:
        send_otp_email(body.email, otp, db_user.username)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"이메일 발송 실패: {str(e)}")

    return {"message": "인증 코드가 발송되었습니다"}


@api_router.post("/auth/verify-otp", response_model=AuthResponse)
def verify_otp(body: VerifyOtpRequest, db: Session = Depends(get_db)):
    """
    OTP 검증 → JWT access_token + refresh_token 발급

    Args:
        body: email, otp

    Returns:
        유저 정보 + JWT 토큰 쌍
    """
    db_user = db.query(User).filter(User.email == body.email).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="가입되지 않은 이메일입니다")
    if db_user.otp_code != body.otp:
        raise HTTPException(status_code=401, detail="인증 코드가 올바르지 않습니다")
    if not db_user.otp_expires_at or datetime.utcnow() > db_user.otp_expires_at:
        raise HTTPException(status_code=401, detail="인증 코드가 만료되었습니다")

    # OTP 사용 후 초기화
    db_user.otp_code = None
    db_user.otp_expires_at = None
    db.commit()

    # JWT 토큰 발급
    access_token = create_access_token(db_user.id, db_user.username)
    refresh_token = create_refresh_token(db_user.id)

    return AuthResponse(
        user=UserResponse.model_validate(db_user),
        access_token=access_token,
        refresh_token=refresh_token,
    )


@api_router.post("/auth/refresh", response_model=AuthResponse)
def refresh_token(body: RefreshRequest, db: Session = Depends(get_db)):
    """
    Refresh token으로 새 access_token 재발급

    Args:
        body: refresh_token

    Returns:
        유저 정보 + 새 JWT 토큰 쌍
    """
    payload = verify_token(body.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="리프레시 토큰이 만료되었습니다. 다시 로그인해주세요.")

    db_user = db.query(User).filter(User.id == int(payload["sub"])).first()
    if not db_user:
        raise HTTPException(status_code=401, detail="존재하지 않는 사용자입니다")

    new_access = create_access_token(db_user.id, db_user.username)
    new_refresh = create_refresh_token(db_user.id)

    return AuthResponse(
        user=UserResponse.model_validate(db_user),
        access_token=new_access,
        refresh_token=new_refresh,
    )


@api_router.get("/auth/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    """현재 로그인된 유저 정보 반환 (토큰 유효성 검증 겸용)"""
    return current_user


# ============ 메시지 API ============

@api_router.get("/messages", response_model=List[MessageResponse])
def get_messages(
    limit: int = 50,
    before_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    """
    메시지 목록 조회
    
    Args:
        limit: 최대 개수
        before_id: 이 ID 이전 메시지만 조회 (페이지네이션)
        db: 데이터베이스 세션
    
    Returns:
        메시지 목록
    """
    query = db.query(Message).join(User)
    
    if before_id:
        query = query.filter(Message.id < before_id)
    
    messages = query.order_by(Message.id.desc()).limit(limit).all()
    
    # 응답 변환
    result = []
    for msg in reversed(messages):
        gif_url = f"/uploads/{msg.gif_path}" if msg.gif_path else None
        result.append(MessageResponse(
            id=msg.id,
            user_id=msg.user_id,
            username=msg.user.username,
            gif_path=msg.gif_path,
            gif_url=gif_url,
            text=msg.text,
            created_at=msg.created_at
        ))
    
    return result


@api_router.post("/messages", response_model=MessageResponse)
async def create_message(
    user_id: int = Form(...),
    text: Optional[str] = Form(None),
    gif: Optional[UploadFile] = File(None),
    gif_base64: Optional[str] = Form(None),
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    """
    메시지 생성 (GIF 업로드 또는 base64) — JWT 인증 필요
    
    Args:
        user_id: 사용자 ID
        text: 텍스트 메시지
        gif: GIF 파일 업로드
        gif_base64: base64 인코딩된 GIF
    
    Returns:
        생성된 메시지
    """
    # JWT 검증 (토큰 있으면 검증, 없으면 기존 방식 호환)
    user = None
    if creds:
        payload = verify_token(creds.credentials)
        if payload and payload.get("type") == "access":
            user = db.query(User).filter(User.id == int(payload["sub"])).first()
    if not user:
        user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    
    gif_path = None
    
    # GIF 파일 저장
    if gif:
        filename = f"{uuid.uuid4()}.gif"
        filepath = os.path.join(UPLOAD_DIR, filename)
        content = await gif.read()
        with open(filepath, "wb") as f:
            f.write(content)
        gif_path = filename
    
    # base64 GIF 저장
    elif gif_base64:
        # data:image/gif;base64, 제거
        if "," in gif_base64:
            gif_base64 = gif_base64.split(",")[1]
        
        filename = f"{uuid.uuid4()}.gif"
        filepath = os.path.join(UPLOAD_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(base64.b64decode(gif_base64))
        gif_path = filename
    
    # 메시지 생성
    db_message = Message(
        user_id=user_id,
        gif_path=gif_path,
        text=text
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    
    # 응답 생성
    gif_url = f"/uploads/{gif_path}" if gif_path else None
    response = MessageResponse(
        id=db_message.id,
        user_id=db_message.user_id,
        username=user.username,
        gif_path=gif_path,
        gif_url=gif_url,
        text=text,
        created_at=db_message.created_at
    )
    
    # WebSocket으로 브로드캐스트
    await manager.broadcast(response.model_dump(mode="json"))
    
    return response


# ============ WebSocket ============

@api_router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocket 연결 엔드포인트
    실시간 메시지 수신용
    """
    await manager.connect(websocket)
    try:
        while True:
            # 클라이언트로부터 메시지 수신 (ping/pong용)
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)


# ============ 헬스체크 ============

@api_router.get("/health")
def health_check():
    """서버 상태 확인"""
    return {"status": "ok", "time": datetime.utcnow().isoformat()}


# API 라우터 등록
app.include_router(api_router)

# Flutter 웹 빌드 정적 파일 서빙
FLUTTER_BUILD_DIR = os.environ.get(
    "FLUTTER_BUILD_DIR",
    os.path.abspath(os.path.join(os.path.dirname(__file__), "../bithabit_flutter/build/web"))
)

if os.path.exists(FLUTTER_BUILD_DIR):
    # Flutter 정적 리소스는 하위 경로로만 마운트 (/ 는 catch-all로 처리)
    app.mount("/assets", StaticFiles(directory=os.path.join(FLUTTER_BUILD_DIR, "assets")), name="assets")
    app.mount("/canvaskit", StaticFiles(directory=os.path.join(FLUTTER_BUILD_DIR, "canvaskit")), name="canvaskit")
    app.mount("/icons", StaticFiles(directory=os.path.join(FLUTTER_BUILD_DIR, "icons")), name="icons")

    @app.get("/{full_path:path}")
    def serve_flutter(full_path: str):
        """Flutter 앱의 모든 경로를 index.html로 서빙 (SPA)"""
        file_path = os.path.join(FLUTTER_BUILD_DIR, full_path)
        if os.path.isfile(file_path):
            return FileResponse(file_path)
        return FileResponse(os.path.join(FLUTTER_BUILD_DIR, "index.html"))
else:
    @app.get("/")
    def root():
        return {"message": "BitHabit API", "flutter_build": "not found"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
