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
  // 发布角色卡：multipart/form-data，body 为 FormData（card=JSON 串，avatar=可选文件）
  uploadCharacter: async (formData) => {
    const res = await fetch(`${BASE_URL}/api/characters`, {
      method: 'POST',
      body: formData,
    });
    let body = null;
    try {
      body = await res.json();
    } catch {
      /* 非 JSON 响应（如文本错误）交下面处理 */
    }
    if (!res.ok) {
      let msg =
        (body && (body.body || body.message)) ||
        (typeof body === 'string' ? body : '');
      if (!msg) {
        // nginx 等网关层直接返回 HTML 错误页（非 JSON）时，映射成可读提示。
        // 413 = 请求体超出 nginx client_max_body_size（默认 1MB，已放宽到 32MB）。
        if (res.status === 413) {
          msg = '文件过大，服务器拒绝了本次上传（超出 32MB 上限）。请压缩立绘图片后重试。';
        } else if (res.status === 502 || res.status === 504) {
          msg = `后端服务无响应（HTTP ${res.status}），请稍后重试。`;
        } else {
          msg = `上传失败（HTTP ${res.status}）`;
        }
      }
      throw new Error(msg);
    }
    return body;
  },
};
