"""
Minimal JWT auth for the login page (patient / clinic roles).

This is a DEMO auth layer: it uses an in-memory user store with PBKDF2-hashed
passwords. For production, replace `USERS` with a real database, move the secret
to a managed secret store, and add registration / password-reset flows.
"""
from __future__ import annotations

import hashlib
import hmac
import os
import time
from typing import Optional

import jwt  # PyJWT
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import config

_bearer = HTTPBearer(auto_error=False)


def _hash(password: str, salt: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 120_000).hex()


def _make_record(password: str, role: str, name: str) -> dict:
    salt = os.urandom(16)
    return {"salt": salt.hex(), "hash": _hash(password, salt), "role": role, "name": name}


# Demo accounts. Both roles can see ALL prediction information; role only
# changes how the app frames it (patient reassurance vs clinical detail).
USERS = {
    "patient": _make_record("patient123", "patient", "Demo Patient"),
    "clinic": _make_record("clinic123", "clinic", "Demo Clinic"),
}


def verify_user(username: str, password: str) -> Optional[dict]:
    rec = USERS.get(username.strip().lower())
    if not rec:
        return None
    calc = _hash(password, bytes.fromhex(rec["salt"]))
    if not hmac.compare_digest(calc, rec["hash"]):
        return None
    return rec


def create_token(username: str, role: str, name: str) -> tuple[str, int]:
    expires_in = config.JWT_EXPIRE_HOURS * 3600
    payload = {
        "sub": username,
        "role": role,
        "name": name,
        "iat": int(time.time()),
        "exp": int(time.time()) + expires_in,
    }
    token = jwt.encode(payload, config.JWT_SECRET, algorithm=config.JWT_ALGORITHM)
    return token, expires_in


def current_user(creds: Optional[HTTPAuthorizationCredentials] = Depends(_bearer)) -> dict:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    try:
        payload = jwt.decode(creds.credentials, config.JWT_SECRET,
                             algorithms=[config.JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token expired")
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    return {"username": payload["sub"], "role": payload.get("role"), "name": payload.get("name")}
