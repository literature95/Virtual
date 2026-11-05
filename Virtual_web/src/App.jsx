import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';
import Home from './pages/Home';
import Characters from './pages/Characters';
import appIcon from './assets/app_icon_grad.png';
import './App.css';

/// 品牌 mark 统一资源：签名渐变透明底图标（导航/页脚/图标/favicon 同源）
export { default as brandMarkUrl } from './assets/app_icon_grad.png';

/** 品牌 mark：与「畅所欲言」同款签名渐变，透明底 */
export function BrandMark({ size = 30 }) {
  return (
    <img
      className="brand-mark-img"
      src={appIcon}
      width={size}
      height={size}
      alt=""
      aria-hidden="true"
      draggable={false}
    />
  );
}

function App() {
  return (
    <BrowserRouter>
      <div className="app">
        {/* 全局星空背景 */}
        <div className="cosmos" aria-hidden="true">
          <div className="stars stars-a" />
          <div className="stars stars-b" />
          <div className="nebula" />
        </div>

        <nav className="nav">
          <Link to="/" className="nav-brand">
            <BrandMark size={28} />
            <span className="nav-word">Virtual</span>
          </Link>
          <div className="nav-right">
            <div className="nav-links">
              <Link to="/">首页</Link>
              <Link to="/characters">角色卡</Link>
            </div>
            <div className="nav-actions">
              <a
                className="nav-github"
                href="https://github.com/literature95/Virtual"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="GitHub 仓库"
                title="GitHub 仓库"
              >
                <svg
                  viewBox="0 0 24 24"
                  width="18"
                  height="18"
                  aria-hidden="true"
                  focusable="false"
                >
                  <path
                    fill="currentColor"
                    d="M12 .5C5.73.5.5 5.74.5 12.02c0 5.09 3.29 9.4 7.86 10.93.58.11.79-.25.79-.56 0-.28-.01-1.02-.02-2-3.2.7-3.88-1.54-3.88-1.54-.52-1.33-1.28-1.68-1.28-1.68-1.05-.72.08-.71.08-.71 1.16.08 1.77 1.2 1.77 1.2 1.03 1.77 2.7 1.26 3.36.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.68 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.18 1.18a11.1 11.1 0 0 1 5.79 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.83 1.19 3.09 0 4.41-2.69 5.38-5.25 5.67.41.36.78 1.06.78 2.14 0 1.55-.01 2.8-.01 3.18 0 .31.21.68.8.56A11.53 11.53 0 0 0 23.5 12.02C23.5 5.74 18.27.5 12 .5Z"
                  />
                </svg>
              </a>
              <a
                className="nav-cta"
                href="/app-release.apk"
                download="Virtual-Android.apk"
              >
                下载 App
              </a>
            </div>
          </div>
        </nav>

        <main className="main">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/characters" element={<Characters />} />
          </Routes>
        </main>

        <footer className="footer">
          <span className="footer-mark">
            <BrandMark size={16} />
          </span>
          <span>Virtual · 本地优先的 AI 角色聊天客户端</span>
          <span className="footer-dim">POWERED BY VIRTUAL_BACKGROUND :8080</span>
        </footer>
      </div>
    </BrowserRouter>
  );
}

export default App;
