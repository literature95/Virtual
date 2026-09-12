import json
import time
import urllib.request
import urllib.error
import sys

BASE = "http://localhost:8080"
results = []


def req(method, path, token=None, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, (json.loads(raw) if raw else None)
        except Exception:
            return e.code, raw


def check(name, cond, detail=""):
    status = "PASS" if cond else "FAIL"
    results.append((status, name, detail))
    print(f"[{status}] {name} {detail}")


ts = int(time.time())

# ---- User A ----
emailA = f"e2e_alice_{ts}@example.com"
s, c = req("POST", "/api/auth/send-code", body={"email": emailA, "purpose": "register"})
dev = (c or {}).get("devCode")
check("A send-code returns devCode", bool(dev), f"status={s} devCode={dev}")

s, r = req("POST", "/api/auth/register",
           body={"email": emailA, "code": dev, "password": "secret123", "nickname": "Alice"})
tokenA = (r or {}).get("token")
idA = ((r or {}).get("user") or {}).get("id")
check("A register -> token+id", bool(tokenA) and bool(idA), f"status={s} id={idA}")

# ---- User B ----
emailB = f"e2e_bob_{ts}@example.com"
s, c = req("POST", "/api/auth/send-code", body={"email": emailB, "purpose": "register"})
dev = (c or {}).get("devCode")
s, r = req("POST", "/api/auth/register",
           body={"email": emailB, "code": dev, "password": "secret123", "nickname": "Bob"})
tokenB = (r or {}).get("token")
idB = ((r or {}).get("user") or {}).get("id")
check("B register -> token+id", bool(tokenB) and bool(idB), f"status={s} id={idB}")

# ---- A creates a post ----
s, r = req("POST", "/api/posts", token=tokenA,
           body={"title": "E2E 测试动态", "content": "这是一条端到端测试帖子",
                 "community": "综合", "type": "text", "tags": ["测试"]})
postId = (r or {}).get("id")
check("A create post -> 201 + id", s == 201 and bool(postId), f"status={s} id={postId}")

# ---- A comments on the post ----
s, r = req("POST", f"/api/posts/{postId}/comments", token=tokenA,
           body={"content": "第一条真实评论"})
commentId = (r or {}).get("id")
check("A comment -> 201 + id", s == 201 and bool(commentId), f"status={s} id={commentId}")

# ---- GET comments ----
s, r = req("GET", f"/api/posts/{postId}/comments")
comments = r if isinstance(r, list) else []
check("GET comments 包含刚发的评论", s == 200 and any(
    cm.get("id") == commentId for cm in comments), f"count={len(comments)}")

# ---- B follows A ----
s, r = req("POST", f"/api/follows/{idA}", token=tokenB)
check("B follow A -> following=true", s == 200 and (r or {}).get("following") is True,
      f"status={s} body={r}")

# ---- GET user profile of A (as B) ----
s, r = req("GET", f"/api/users/{idA}", token=tokenB)
prof = r or {}
check("GET /api/users/[id] isFollowing=true", prof.get("isFollowing") is True,
      f"isFollowing={prof.get('isFollowing')} followerCount={prof.get('followerCount')}")
check("GET /api/users/[id] 含帖子列表", isinstance(prof.get("posts"), list) and len(prof.get("posts", [])) >= 1,
      f"posts={len(prof.get('posts', []))}")

# ---- GET post detail ----
s, r = req("GET", f"/api/posts/{postId}", token=tokenB)
detail = r or {}
check("GET /api/posts/[id] 详情", s == 200 and detail.get("id") == postId, f"status={s}")
check("post detail isFollowingAuthor=true", detail.get("isFollowingAuthor") is True,
      f"isFollowingAuthor={detail.get('isFollowingAuthor')}")
check("post detail comments 计数>=1", (detail.get("comments") or 0) >= 1,
      f"comments={detail.get('comments')}")

# ---- B's follow list contains A ----
s, r = req("GET", "/api/follows", token=tokenB)
fl = r if isinstance(r, list) else []
check("GET /api/follows 含 A", any(f.get("id") == idA for f in fl), f"follows={len(fl)}")

# ============ 个人信息编辑 / 修改密码（2026-09-12 新增） ============

# ---- PATCH /api/users/me 更新昵称/简介/头像 ----
s, r = req("PATCH", "/api/users/me", token=tokenA,
           body={"nickname": "Alice改", "bio": "这是个人简介", "avatarUrl": ""})
u = (r or {}).get("user") or {}
check("PATCH /api/users/me 昵称生效", s == 200 and u.get("nickname") == "Alice改",
      f"status={s} nickname={u.get('nickname')}")
check("PATCH /api/users/me 简介生效", u.get("bio") == "这是个人简介", f"bio={u.get('bio')}")

# ---- me 接口能读回 bio ----
s, r = req("GET", "/api/auth/me", token=tokenA)
me = (r or {}).get("user") or {}
check("GET /api/auth/me 含 bio", me.get("bio") == "这是个人简介", f"bio={me.get('bio')}")

# ---- 空昵称被拒 ----
s, r = req("PATCH", "/api/users/me", token=tokenA, body={"nickname": "   "})
check("PATCH 空昵称 -> 400", s == 400, f"status={s} body={r}")

# ---- 未登录改资料被拒 ----
s, r = req("PATCH", "/api/users/me", body={"nickname": "黑客"})
check("PATCH 未登录 -> 401", s == 401, f"status={s}")

# ---- 用户主页展示 bio ----
s, r = req("GET", f"/api/users/{idA}")
check("GET /api/users/[id] 含 bio", (r or {}).get("bio") == "这是个人简介",
      f"bio={(r or {}).get('bio')}")

# ---- 修改密码：旧密码错误被拒 ----
s, r = req("POST", "/api/auth/change-password", token=tokenA,
           body={"oldPassword": "wrongpass", "newPassword": "newsecret1"})
check("change-password 旧密码错 -> 400", s == 400, f"status={s} body={r}")

# ---- 修改密码：新密码过短被拒 ----
s, r = req("POST", "/api/auth/change-password", token=tokenA,
           body={"oldPassword": "secret123", "newPassword": "123"})
check("change-password 新密码过短 -> 400", s == 400, f"status={s} body={r}")

# ---- 修改密码：正确旧密码成功 ----
s, r = req("POST", "/api/auth/change-password", token=tokenA,
           body={"oldPassword": "secret123", "newPassword": "newsecret1"})
check("change-password 成功", s == 200 and (r or {}).get("ok") is True,
      f"status={s} body={r}")

# ---- 旧密码失效，新密码可登录 ----
s, r = req("POST", "/api/auth/login", body={"email": emailA, "password": "secret123"})
check("旧密码登录 -> 401", s == 401, f"status={s}")
s, r = req("POST", "/api/auth/login", body={"email": emailA, "password": "newsecret1"})
check("新密码登录 -> 200", s == 200 and bool((r or {}).get("token")), f"status={s}")

# ---- 忘记密码：验证码重置 ----
s, c = req("POST", "/api/auth/send-code", body={"email": emailA, "purpose": "reset"})
dev = (c or {}).get("devCode")
check("reset send-code 返回 devCode", bool(dev), f"status={s} devCode={dev}")
s, r = req("POST", "/api/auth/reset-password",
           body={"email": emailA, "code": dev, "newPassword": "resetpass9"})
check("reset-password 成功", s == 200 and (r or {}).get("ok") is True,
      f"status={s} body={r}")
s, r = req("POST", "/api/auth/login", body={"email": emailA, "password": "resetpass9"})
check("重置后新密码可登录", s == 200 and bool((r or {}).get("token")), f"status={s}")

# ---- 重置：错误验证码被拒 ----
s, c = req("POST", "/api/auth/send-code", body={"email": emailA, "purpose": "reset"})
s, r = req("POST", "/api/auth/reset-password",
           body={"email": emailA, "code": "000000", "newPassword": "whatever1"})
check("reset-password 错误验证码 -> 400", s == 400, f"status={s} body={r}")


# ---- summary ----
failed = [n for st, n, _ in results if st == "FAIL"]
print("\n==== SUMMARY ====")
print(f"TOTAL={len(results)} PASS={len(results)-len(failed)} FAIL={len(failed)}")
sys.exit(1 if failed else 0)
