import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/client';
import { extractCharaFromPng, stripDataAvatar } from '../lib/charaCard';

// 每页 30 张（一行 6 个 × 5 行）；列数由 CSS 控制，随屏宽自适应。
const PER_PAGE = 30;

// ── 简介预处理（与 App 端 CharacterCoverCard.coverSummaryOf 对齐）──
// 角色卡 description 多为「字段名：值」结构化文本（姓名 / 年龄 / 身份 / …）。
// 值不足 20 字的视为元信息丢弃，只取最长的一段作为封面简介；无字段结构则
// 退化为连贯文本。字段名限定 ≤4 字，避免把「这件事很重要：…」误判为字段行。
const FIELD_LINE = /^[^：:\n]{1,4}[：:]\s*(.+)$/;
const MIN_PARAGRAPH = 20;
const flatten = (s) => s.replace(/\s+/g, ' ').trim();

function coverSummaryOf(description) {
  const text = (description ?? '').trim();
  if (!text) return '';
  const paragraphs = [];
  const prose = [];
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line) continue;
    const m = FIELD_LINE.exec(line);
    if (!m) {
      prose.push(line);
      continue;
    }
    const value = m[1].trim();
    if (value.length >= MIN_PARAGRAPH) paragraphs.push(value);
  }
  if (paragraphs.length) {
    return flatten(paragraphs.reduce((a, b) => (b.length > a.length ? b : a)));
  }
  if (prose.length) return flatten(prose.join(' '));
  return '';
}

function matchesQuery(c, q) {
  if (!q) return true;
  const hay = [c.name, c.description, c.creator, ...(c.tags ?? [])]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
  return hay.includes(q);
}

function hasAnyTag(c, tags) {
  if (!tags || tags.length === 0) return true;
  const set = new Set(c.tags ?? []);
  return tags.some((t) => set.has(t));
}

export default function Characters() {
  const [chars, setChars] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [input, setInput] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [activeTags, setActiveTags] = useState([]); // 多选（OR）
  const [sort, setSort] = useState('new'); // 'new' | 'hot'
  const [showUpload, setShowUpload] = useState(false);

  // 上传表单状态
  const [upFile, setUpFile] = useState(null);
  const [upAvatar, setUpAvatar] = useState(null);
  const [upText, setUpText] = useState('');
  const [upName, setUpName] = useState('');
  const [upBusy, setUpBusy] = useState(false);
  const [upMsg, setUpMsg] = useState(null); // { type: 'ok' | 'err', text }

  function normalize(list) {
    const arr = Array.isArray(list) ? list : list?.value ?? [];
    return arr.map((c) => ({
      ...c,
      updatedAt: c.updatedAt ?? c.updated_at ?? null,
      popularity: typeof c.popularity === 'number' ? c.popularity : 0,
    }));
  }

  function load() {
    setLoading(true);
    api.characters()
      .then((list) => {
        setChars(normalize(list));
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }

  useEffect(() => {
    load();
  }, []);

  useEffect(() => {
    if (!selected?.id) return;
    api.character(selected.id)
      .then((full) => setSelected(full.value ?? full))
      .catch(() => {});
  }, [selected?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    document.body.style.overflow = selected || showUpload ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [selected, showUpload]);

  // 标签词表（按出现频次降序，再按名称）
  const allTags = useMemo(() => {
    const freq = new Map();
    for (const c of chars) for (const t of c.tags ?? []) freq.set(t, (freq.get(t) || 0) + 1);
    return [...freq.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map((e) => e[0]);
  }, [chars]);

  // 全量客户端筛选 + 排序（列表接口一次性返回全部角色卡）
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    const list = chars.filter((c) => matchesQuery(c, q) && hasAnyTag(c, activeTags));
    const sorted = [...list];
    if (sort === 'hot') {
      sorted.sort((a, b) => (b.popularity || 0) - (a.popularity || 0));
    } else {
      sorted.sort(
        (a, b) =>
          (b.updatedAt || '').localeCompare(a.updatedAt || '') ||
          String(b.id).localeCompare(String(a.id)),
      );
    }
    return sorted;
  }, [chars, query, activeTags, sort]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PER_PAGE));
  const current = Math.min(page, totalPages);
  const pageItems = filtered.slice((current - 1) * PER_PAGE, current * PER_PAGE);

  const submitSearch = (e) => {
    e.preventDefault();
    setQuery(input);
    setPage(1);
  };

  const toggleTag = (t) => {
    setActiveTags((prev) => (prev.includes(t) ? prev.filter((x) => x !== t) : [...prev, t]));
    setPage(1);
  };
  const clearTags = () => {
    setActiveTags([]);
    setPage(1);
  };

  // 页码序列（首尾固定 + 当前页附近窗口，其余省略为 …）
  const pageNumbers = useMemo(() => {
    const win = 2;
    const out = [];
    for (let p = 1; p <= totalPages; p++) {
      if (p === 1 || p === totalPages || (p >= current - win && p <= current + win)) {
        out.push(p);
      } else if (out[out.length - 1] !== '…') {
        out.push('…');
      }
    }
    return out;
  }, [totalPages, current]);

  // ── 上传相关 ──
  const onPickCard = async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setUpFile(f);
    setUpMsg(null);
    try {
      let obj;
      // 按扩展名/MIME 判定，不依赖 MIME 是否被浏览器识别（中文文件名时为空的浏览器也有）
      if (f.type === 'image/png' || /\.png$/i.test(f.name)) {
        obj = await extractCharaFromPng(f);
      } else {
        obj = JSON.parse((await f.text()).replace(/^\uFEFF/, ''));
      }
      obj = stripDataAvatar(obj);
      const data = obj?.data ?? obj; // 兼容 {spec,data} 信封与裸 data
      setUpName(data?.name ?? obj?.name ?? '');
      setUpText(JSON.stringify(obj, null, 2));
    } catch (err) {
      setUpMsg({ type: 'err', text: '解析失败：' + (err.message || err) });
      setUpName('');
      // 清空文本域：否则上一次解析成功的 JSON 会留在框里，用户点「发布」会把
      // 旧卡当成这次选中的文件发出去（错误提示与实际行为不一致）。
      setUpText('');
    }
  };

  const onUpload = async (e) => {
    e.preventDefault();
    let cardObj;
    try {
      cardObj = JSON.parse(upText.replace(/^\uFEFF/, ''));
    } catch {
      setUpMsg({ type: 'err', text: '角色卡 JSON 解析失败，请检查格式' });
      return;
    }
    const form = new FormData();
    form.append('card', JSON.stringify(cardObj));
    if (upAvatar) form.append('avatar', upAvatar);
    setUpBusy(true);
    setUpMsg(null);
    try {
      await api.uploadCharacter(form);
      setUpMsg({ type: 'ok', text: '上传成功，已加入角色库' });
      // 重置筛选条件，确保新卡可见并置顶（最新）
      setActiveTags([]);
      setQuery('');
      setInput('');
      setSort('new');
      setPage(1);
      await load();
      setTimeout(() => setShowUpload(false), 900);
    } catch (err) {
      setUpMsg({ type: 'err', text: err.message || '上传失败' });
    } finally {
      setUpBusy(false);
    }
  };

  const filterActive = query.trim().length > 0 || activeTags.length > 0;

  return (
    <div className="characters-page">
      <header className="page-head">
        <span className="mono section-tag">// CHARACTERS</span>
        <h1>角色卡</h1>
        <p>每一位角色，都是一段未曾发生的故事</p>
      </header>

      {/* 顶部居中搜索栏 */}
      <div className="char-search">
        <form className="search-box" onSubmit={submitSearch} role="search">
          <span className="search-ico" aria-hidden="true">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="7" />
              <path d="M21 21l-4.3-4.3" />
            </svg>
          </span>
          <input
            type="search"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="搜索角色名称 / 简介 / 标签"
            aria-label="搜索角色卡"
          />
          <button type="submit" className="search-btn">搜索</button>
        </form>
      </div>

      {/* 工具栏：排序 + 上传 */}
      <div className="char-toolbar">
        <div className="seg" role="tablist" aria-label="排序方式">
          <button
            type="button"
            role="tab"
            aria-selected={sort === 'new'}
            className={sort === 'new' ? 'active' : ''}
            onClick={() => setSort('new')}
          >
            最新
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={sort === 'hot'}
            className={sort === 'hot' ? 'active' : ''}
            onClick={() => setSort('hot')}
          >
            最热
          </button>
        </div>
        <div className="toolbar-spacer" />
        <button type="button" className="upload-btn" onClick={() => setShowUpload(true)}>
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M12 16V4M7 9l5-5 5 5" />
            <path d="M5 20h14" />
          </svg>
          上传角色卡
        </button>
      </div>

      {/* 标签筛选 */}
      {allTags.length > 0 && (
        <div className="char-tags">
          <button
            type="button"
            className={`tag-chip ${activeTags.length === 0 ? 'active' : ''}`}
            onClick={clearTags}
          >
            全部
          </button>
          {allTags.map((t) => (
            <button
              type="button"
              key={t}
              className={`tag-chip ${activeTags.includes(t) ? 'active' : ''}`}
              onClick={() => toggleTag(t)}
            >
              {t}
            </button>
          ))}
        </div>
      )}

      {loading && (
        <div className="loading mono">
          <span className="live-dot on" /> 正在加载角色…
        </div>
      )}
      {error && <div className="error-tip mono">LOAD FAILED · {error}</div>}

      {!loading && !error && (
        <>
          <div className="char-count mono">
            {filterActive
              ? `命中 ${filtered.length} / ${chars.length} 张`
              : `共 ${chars.length} 张角色卡`}
            {totalPages > 1 && ` · 第 ${current} / ${totalPages} 页`}
          </div>

          {pageItems.length === 0 ? (
            <div className="char-empty mono">没有匹配的角色卡</div>
          ) : (
            <div className="char-grid">
              {pageItems.map((c, i) => {
                const summary = coverSummaryOf(c.description);
                return (
                  <button
                    key={c.id}
                    type="button"
                    className="char-tile"
                    style={{ '--d': `${Math.min(i, 12) * 45}ms` }}
                    onClick={() => setSelected(c)}
                    title={c.name}
                  >
                    <span className="fallback-cover" aria-hidden="true">{c.name?.charAt(0)}</span>
                    {c.avatarUrl && (
                      <img
                        className="char-cover"
                        src={c.avatarUrl}
                        alt={c.name}
                        loading="lazy"
                        onError={(e) => { e.currentTarget.style.display = 'none'; }}
                      />
                    )}
                    <span className="tile-shade" />
                    {(c.tags ?? []).length > 0 && (
                      <span className="tile-chip">{c.tags[0]}</span>
                    )}
                    <span className="tile-body">
                      <h3>{c.name}</h3>
                      {summary && <p>{summary}</p>}
                    </span>
                  </button>
                );
              })}
            </div>
          )}

          {totalPages > 1 && (
            <nav className="pager" aria-label="分页">
              <button
                type="button"
                onClick={() => setPage(current - 1)}
                disabled={current <= 1}
              >
                上一页
              </button>
              {pageNumbers.map((p, idx) =>
                p === '…' ? (
                  <span key={`e${idx}`} className="pager-ellipsis">…</span>
                ) : (
                  <button
                    type="button"
                    key={p}
                    className={p === current ? 'active' : ''}
                    onClick={() => setPage(p)}
                  >
                    {p}
                  </button>
                )
              )}
              <button
                type="button"
                onClick={() => setPage(current + 1)}
                disabled={current >= totalPages}
              >
                下一页
              </button>
            </nav>
          )}
        </>
      )}

      {selected && (
        <div className="veil" onClick={() => setSelected(null)}>
          <article className="sheet" onClick={(e) => e.stopPropagation()}>
            <button className="sheet-close" onClick={() => setSelected(null)} aria-label="关闭">×</button>

            <header className="sheet-head">
              <span className="bubble-avatar lg">
                <span>{selected.name.charAt(0)}</span>
              </span>
              <div>
                <h2>{selected.name}</h2>
                <div className="peek-tags">
                  {(selected.tags ?? []).map((t) => (
                    <span key={t} className="mono">{t}</span>
                  ))}
                </div>
              </div>
            </header>

            {selected.description && (
              <section className="sheet-sec">
                <h4 className="mono">// INTRO</h4>
                <p>{selected.description}</p>
              </section>
            )}
            {selected.persona && (
              <section className="sheet-sec">
                <h4 className="mono">// PERSONA</h4>
                <p>{selected.persona}</p>
              </section>
            )}
            {selected.greeting && (
              <section className="sheet-sec">
                <h4 className="mono">// GREETING</h4>
                <p className="sheet-quote">{selected.greeting}</p>
              </section>
            )}
            {selected.firstMessage && (
              <section className="sheet-sec">
                <h4 className="mono">// FIRST MESSAGE</h4>
                <pre className="sheet-quote">{selected.firstMessage}</pre>
              </section>
            )}

            <footer className="sheet-foot mono">
              在 App 中导入该角色卡即可开始对话
            </footer>
          </article>
        </div>
      )}

      {/* 上传角色卡弹层 */}
      {showUpload && (
        <div className="veil" onClick={() => !upBusy && setShowUpload(false)}>
          <div className="sheet upload-sheet" onClick={(e) => e.stopPropagation()}>
            <button
              className="sheet-close"
              onClick={() => !upBusy && setShowUpload(false)}
              aria-label="关闭"
            >
              ×
            </button>
            <h2 className="upload-title">上传角色卡</h2>
            <form className="upload-form" onSubmit={onUpload}>
              <label className="upload-field">
                <span className="upload-label">角色卡文件（.json 或 .png 立绘卡）</span>
                <input
                  type="file"
                  accept=".json,application/json,.png,image/png"
                  onChange={onPickCard}
                />
              </label>
              <p className="upload-hint mono">或直接粘贴角色卡 JSON：</p>
              <textarea
                className="upload-json"
                value={upText}
                onChange={(e) => setUpText(e.target.value)}
                placeholder='{"name":"角色名","description":"...","tags":["治愈"]}'
                spellCheck={false}
              />
              <label className="upload-field">
                <span className="upload-label">立绘（可选）</span>
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => setUpAvatar(e.target.files?.[0] ?? null)}
                />
              </label>
              {upName && <div className="upload-name mono">解析到：{upName}</div>}
              {upMsg && <div className={`upload-msg ${upMsg.type}`}>{upMsg.text}</div>}
              <div className="upload-actions">
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => setShowUpload(false)}
                  disabled={upBusy}
                >
                  取消
                </button>
                <button
                  type="submit"
                  className="upload-submit"
                  disabled={upBusy || !upText.trim()}
                >
                  {upBusy ? '上传中…' : '发布'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
