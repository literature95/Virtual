// API 客户端 — 默认走相对路径（Vite proxy 到 Virtual_background:8080）
// 生产部署时可改为绝对 URL
const BASE_URL = import.meta.env.VITE_API_BASE || '';

async function request(path) {
  const res = await fetch(`${BASE_URL}${path}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export const api = {
  health: () => request('/api/health'),
  metadata: (params = {}) => {
    const q = new URLSearchParams(params).toString();
    return request(`/api/metadata${q ? '?' + q : ''}`);
  },
  characters: () => request('/api/characters'),
  character: (id) => request(`/api/characters/${id}`),
  appInfo: () => request('/api/app-info'),
};
