from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import ARRAY, Boolean, CheckConstraint, Date, DateTime, ForeignKey, Index, JSON, Numeric, String, Text, Uuid, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class UUIDTimestampMixin:
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class User(UUIDTimestampMixin, Base):
    __tablename__ = "users"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")

    __table_args__ = (
        Index("ix_users_email_lower", func.lower(email), unique=True),
    )


class Consent(UUIDTimestampMixin, Base):
    __tablename__ = "consents"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    version: Mapped[str] = mapped_column(String(32), nullable=False)
    accepted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ip: Mapped[str | None] = mapped_column(String(45), nullable=True)

    __table_args__ = (
        Index("ix_consents_user_id_type", "user_id", "type"),
    )


class RefreshToken(UUIDTimestampMixin, Base):
    __tablename__ = "refresh_tokens"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    family_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False, index=True)
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    replaced_by: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("refresh_tokens.id", ondelete="SET NULL"),
        nullable=True,
    )

    __table_args__ = (
        Index("ix_refresh_tokens_token_hash", "token_hash", unique=True),
    )


class PasswordResetToken(UUIDTimestampMixin, Base):
    __tablename__ = "password_reset_tokens"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_password_reset_tokens_token_hash", "token_hash", unique=True),
    )


class Category(UUIDTimestampMixin, Base):
    __tablename__ = "categories"

    user_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index(
            "ix_categories_user_name_type",
            "user_id",
            "name",
            "type",
            unique=True,
            postgresql_nulls_not_distinct=True,
        ),
    )


class Transaction(UUIDTimestampMixin, Base):
    __tablename__ = "transactions"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    type: Mapped[str] = mapped_column(String(20), nullable=False)
    amount: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    description: Mapped[str] = mapped_column(String(100), nullable=False)
    category_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("categories.id", ondelete="NO ACTION"),
        nullable=True,
        index=True,
    )
    date: Mapped[object] = mapped_column(Date, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_transactions_user_date", "user_id", "date"),
        CheckConstraint("amount > 0", name="ck_transactions_amount_positive"),
    )


class ExchangeCredential(UUIDTimestampMixin, Base):
    __tablename__ = "exchange_credentials"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    exchange: Mapped[str] = mapped_column(String(32), nullable=False)
    api_key_enc: Mapped[str] = mapped_column(Text, nullable=False)
    api_secret_enc: Mapped[str] = mapped_column(Text, nullable=False)
    key_hint: Mapped[str] = mapped_column(String(64), nullable=False)
    key_version: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    last_checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_exchange_credentials_user_exchange", "user_id", "exchange", unique=True),
    )


class PortfolioPosition(UUIDTimestampMixin, Base):
    __tablename__ = "portfolio_positions"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    asset_symbol: Mapped[str] = mapped_column(String(16), nullable=False)
    quantity: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    average_buy_price: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_portfolio_positions_user_symbol", "user_id", "asset_symbol", unique=True),
    )


class BotSetting(UUIDTimestampMixin, Base):
    __tablename__ = "bot_settings"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    mode: Mapped[str] = mapped_column(String(16), nullable=False, default="PAPER", server_default="PAPER")
    state: Mapped[str] = mapped_column(String(32), nullable=False, default="STOPPED", server_default="STOPPED")
    strategy_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    strategy_params: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict, server_default='{}')
    max_capital_allocation: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    max_order_size: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    max_daily_loss: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    max_total_loss: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    risk_level: Mapped[str | None] = mapped_column(String(16), nullable=True)
    allowed_pairs: Mapped[list[str] | None] = mapped_column(ARRAY(String), nullable=True)
    paper_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint("mode IN ('PAPER', 'LIVE')", name="ck_bot_settings_mode"),
    )


class BotOrder(UUIDTimestampMixin, Base):
    __tablename__ = "bot_orders"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    pair: Mapped[str] = mapped_column(String(32), nullable=False)
    side: Mapped[str] = mapped_column(String(8), nullable=False)
    quantity: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    price: Mapped[object] = mapped_column(Numeric(20, 8), nullable=False)
    fee: Mapped[object | None] = mapped_column(Numeric(20, 8), nullable=True)
    fee_asset: Mapped[str | None] = mapped_column(String(16), nullable=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    client_order_id: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    exchange_order_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    is_simulated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default='false')
    signal_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    strategy_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    executed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index("ix_bot_orders_user_executed_at", "user_id", "executed_at"),
        CheckConstraint("side IN ('BUY', 'SELL')", name="ck_bot_orders_side"),
        CheckConstraint("quantity > 0", name="ck_bot_orders_quantity_positive"),
        CheckConstraint("price > 0", name="ck_bot_orders_price_positive"),
    )


class BotRunLog(UUIDTimestampMixin, Base):
    __tablename__ = "bot_run_logs"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    cycle_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    outcome: Mapped[str] = mapped_column(String(32), nullable=False)
    details: Mapped[dict] = mapped_column(JSONB, nullable=False)


class AuditEvent(Base):
    __tablename__ = "audit_events"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), nullable=True, index=True)
    actor: Mapped[str] = mapped_column(String(32), nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), index=True
    )
