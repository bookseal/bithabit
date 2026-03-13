"""
데이터베이스 모델 정의
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    """사용자 모델"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=True)  # 이메일 (신규)
    otp_code = Column(String(6), nullable=True)                          # OTP 코드
    otp_expires_at = Column(DateTime, nullable=True)                     # OTP 만료 시각
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # 관계 설정
    messages = relationship("Message", back_populates="user")
    
    def __repr__(self) -> str:
        return f"<User(id={self.id}, username={self.username}, email={self.email})>"


class Message(Base):
    """메시지 모델 (GIF 포함)"""
    __tablename__ = "messages"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    gif_path = Column(String(255), nullable=True)  # GIF 파일 경로
    text = Column(Text, nullable=True)  # 텍스트 메시지
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # 관계 설정
    user = relationship("User", back_populates="messages")
    
    def __repr__(self) -> str:
        return f"<Message(id={self.id}, user_id={self.user_id})>"
