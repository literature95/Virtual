import { useEffect, useState } from 'react';
import { api } from '../api/client';

export default function Characters() {
  const [chars, setChars] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    api.characters()
      .then((list) => {
        setChars(list.value ?? list);
        setLoading(false);
      })
      .catch((e) => {
        setError(e.message);
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    if (!selected?.id) return;
    api.character(selected.id)
      .then((full) => setSelected(full.value ?? full))
      .catch(() => {});
  }, [selected?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    document.body.style.overflow = selected ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [selected]);

  return (
    <div className="characters-page">
      <header className="page-head">
        <span className="mono section-tag">// CHARACTERS</span>
        <h1>角色卡</h1>
        <p>每一位角色，都是一段未曾发生的故事</p>
      </header>

      {loading && (
        <div className="loading mono">
          <span className="live-dot on" /> 正在从 :8080 加载角色…
        </div>
      )}
      {error && <div className="error-tip mono">LOAD FAILED · {error}</div>}

      <div className="char-grid">
        {chars.map((c, i) => (
          <button
            key={c.id}
            className="char-card photo"
            style={{ '--d': `${i * 70}ms` }}
            onClick={() => setSelected(c)}
          >
            {c.avatarUrl && (
              <img
                className="char-photo"
                src={c.avatarUrl}
                alt={c.name}
                loading="lazy"
                onError={(e) => { e.currentTarget.style.display = 'none'; }}
              />
            )}
            <span className="char-fallback" aria-hidden="true">{c.name.charAt(0)}</span>
            <span className="char-shade" />
            <span className="char-overlay">
              <h3>{c.name}</h3>
              <p>{c.description}</p>
              <span className="peek-tags">
                {(c.tags ?? []).map((t) => (
                  <span key={t} className="mono">{t}</span>
                ))}
              </span>
            </span>
            <span className="char-go mono">VIEW →</span>
          </button>
        ))}
      </div>

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
    </div>
  );
}
