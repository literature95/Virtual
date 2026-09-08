import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';
import Home from './pages/Home';
import Characters from './pages/Characters';
import './App.css';

/** 品牌 mark：对话气泡 + 渐变 + V 字 */
export function BrandMark({ size = 30 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <defs>
        <linearGradient id="bm-g" x1="0" y1="0" x2="64" y2="64" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#7E4DF1" />
          <stop offset=".86" stopColor="#E3756E" />
          <stop offset="1" stopColor="#E58029" />
        </linearGradient>
      </defs>
      <path
        d="M32 4C16.5 4 4 15.2 4 29c0 7.9 4.1 15 10.6 19.6-.4 3.4-1.8 7.6-5 10.4-.8.7-.4 2 .6 2.1 5.9.5 10.9-1.6 14.3-3.9 2.4.6 4.9.9 7.5.9 15.5 0 28-11.2 28-25S47.5 4 32 4z"
        fill="url(#bm-g)"
      />
      <path d="M24 20l8 24 8-24h-7l-1.6 6.2L30 20h-6z" fill="#141414" />
    </svg>
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
            <a
              className="nav-cta"
              href="#download"
              onClick={(e) => {
                e.preventDefault();
                document.getElementById('download')?.scrollIntoView({ behavior: 'smooth' });
              }}
            >
              下载 App
            </a>
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
