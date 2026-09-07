import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { BrandMark } from '../App';

/* 漂浮玻璃胶囊 —— 复刻 Tavo 主视觉的技能胶囊 */
const CAPSULES = [
  { icon: '◈', label: '多模型接入', cls: 'c1' },
  { icon: '☽', label: '深夜食堂', cls: 'c2' },
  { icon: '✦', label: '本地优先', cls: 'c3' },
  { icon: '⌁', label: '流式对话', cls: 'c4' },
  { icon: '❋', label: '角色卡', cls: 'c5' },
];

/* 手机 mockup 里的模拟聊天 */
const MOCK = {
  name: '晓夜',
  scene: ['🏮 : 深夜 · 便利店', '📍 : 街角'],
  lines: [
    { who: 'sys', text: '暖黄的灯光洒在湿漉漉的地板上。' },
    { who: 'ai', text: '「欢迎光临~ 这么晚了还没休息吗？需要帮你热一碗关东煮吗？」' },
  ],
};

const FEATURES = [
  { no: '01', title: '跨模型自由接入', desc: 'OpenAI · Anthropic · Gemini · DeepSeek，一个应用切换全部主流模型。', accent: '#7E4DF1' },
  { no: '02', title: '角色卡扮演系统', desc: '导入 SillyTavern 角色卡，或从零捏出你的专属角色，世界书与正则齐备。', accent: '#E3756E' },
  { no: '03', title: '本地优先存储', desc: '对话与角色数据留在你的设备里，离线可用，隐私自己掌管。', accent: '#34d399' },
  { no: '04', title: '沉浸式流式对话', desc: '打字机实时输出，立绘、状态标签与多模态消息，如临真实对话。', accent: '#E58029' },
];

export default function Home() {
  const [appInfo, setAppInfo] = useState(null);
  const [chars, setChars] = useState([]);
  const [live, setLive] = useState(false);

  useEffect(() => {
    api.appInfo().then(setAppInfo).catch(() => {});
    api.health().then(() => setLive(true)).catch(() => setLive(false));
    api.characters()
      .then((list) => setChars((list.value ?? list).slice(0, 3)))
      .catch(() => {});
  }, []);

  return (
    <div className="home">
      {/* ============ HERO ============ */}
      <section className="hero">
        <div className="hero-copy">
          <div className="hero-status reveal">
            <span className={`live-dot ${live ? 'on' : ''}`} />
            <span className="mono">{live ? 'VIRTUAL_BACKGROUND ONLINE' : 'OFFLINE DEMO'}</span>
          </div>

          <h1 className="hero-title">
            <span className="reveal r1">与虚拟角色</span>
            <span className="reveal r2">畅所欲言</span>
          </h1>

          <p className="hero-slogan reveal r3">
            构建专属你的 <em>AI 社交世界</em> —— 角色扮演 · 本地优先 · 跨模型
          </p>

          <div className="hero-cta reveal r4" id="download">
            <a className="btn-grad" href={appInfo?.downloadUrl || '#'}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 3v12m0 0l-5-5m5 5l5-5" />
                <path d="M4 21h16" />
              </svg>
              下载 Android 版
            </a>
            <Link className="btn-ghost" to="/characters">
              浏览角色卡 <span className="arrow">→</span>
            </Link>
          </div>

          <div className="hero-meta mono reveal r5">
            <span>{appInfo?.name ?? 'Virtual'} v{appInfo?.version ?? '1.0.0'}</span>
            <i>/</i>
            <span>FLUTTER · DART FROG · REACT</span>
          </div>
        </div>

        {/* 漂浮胶囊 + 手机 mockup */}
        <div className="hero-visual">
          {CAPSULES.map((c, i) => (
            <span key={c.cls} className={`capsule ${c.cls} reveal`} style={{ animationDelay: `${0.5 + i * 0.12}s` }}>
              <b>{c.icon}</b> {c.label}
            </span>
          ))}

          <div className="phone reveal r3" role="img" aria-label="应用界面预览">
            <div className="phone-notch" />
            <div className="phone-screen">
              <div className="chat-top">
                <span className="chat-menu">≡</span>
                <span className="chat-name">{MOCK.name}</span>
                <span className="chat-refresh">⟳</span>
              </div>
              <div className="chat-body">
                <div className="chat-scenes">
                  {MOCK.scene.map((s) => (
                    <span key={s} className="scene-tag mono">{s}</span>
                  ))}
                </div>
                {MOCK.lines.map((l, i) => (
                  <div key={i} className={`bubble ${l.who}`}>
                    {l.text}
                  </div>
                ))}
              </div>
              <div className="chat-input">
                <span className="plus">＋</span>
                <span className="placeholder">说点什么…</span>
                <span className="send">↑</span>
              </div>
            </div>
            <div className="phone-glow" />
          </div>
        </div>
      </section>

      {/* ============ FEATURES ============ */}
      <section className="features">
        <div className="features-head">
          <span className="mono section-tag">// WHY VIRTUAL</span>
          <h2>为沉浸而生</h2>
        </div>
        <div className="feature-list">
          {FEATURES.map((f, i) => (
            <article className="feature-row" key={f.no} style={{ '--accent': f.accent }}>
              <span className="feature-no mono">{f.no}</span>
              <div className="feature-text">
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      {/* ============ CHARACTERS PREVIEW ============ */}
      {chars.length > 0 && (
        <section className="peek">
          <div className="features-head">
            <span className="mono section-tag">// CHARACTERS</span>
            <h2>正在等待你的角色</h2>
          </div>
          <div className="peek-grid">
            {chars.map((c) => (
              <Link to="/characters" key={c.id} className="char-card photo peek">
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
                    {(c.tags ?? []).slice(0, 3).map((t) => (
                      <span key={t} className="mono">{t}</span>
                    ))}
                  </span>
                </span>
              </Link>
            ))}
          </div>
          <Link to="/characters" className="peek-more">
            查看全部角色 <span className="arrow">→</span>
          </Link>
        </section>
      )}

      {/* ============ DOWNLOAD BAND ============ */}
      <section className="band">
        <BrandMark size={44} />
        <h2>现在，开启你的故事</h2>
        <p>{appInfo?.description ?? '本地优先 · 角色扮演 · 跨模型接入的 AI 角色聊天客户端'}</p>
        <a className="btn-grad big" href={appInfo?.downloadUrl || '#'}>
          免费下载 <span className="mono">APK</span>
        </a>
      </section>
    </div>
  );
}
