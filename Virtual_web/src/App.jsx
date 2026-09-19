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
            <a
              className="nav-cta"
              href="/app-release.apk"
              download="Virtual-Android.apk"
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
