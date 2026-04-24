<script setup lang="ts">
import { ref } from "vue";

const output = ref("（尚未提交）");
const busy = ref(false);

async function onSubmit(e: Event) {
  e.preventDefault();
  const form = e.target as HTMLFormElement;
  const fd = new FormData(form);
  busy.value = true;
  output.value = "请求中…";
  try {
    const r = await fetch("/api/submit", { method: "POST", body: fd });
    const text = await r.text();
    output.value = `${r.status} ${r.statusText}\n${text}`;
  } catch (err) {
    output.value = `网络错误: ${err}`;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="page">
    <h1>Vue 3 静态页（Vite）</h1>
    <p class="hint">
      开发模式下 <code>/api/*</code> 由 Vite 代理到 Node API（默认
      <code>127.0.0.1:5094</code>）；生产构建后由 Nginx 反代同源
      <code>/api</code>。
    </p>

    <form @submit="onSubmit">
      <label>名称 <input name="name" type="text" required placeholder="必填" /></label>
      <label>备注 <textarea name="remark" rows="3" placeholder="可选" /></label>
      <label>附件 <input name="file" type="file" /></label>
      <button type="submit" :disabled="busy">提交（multipart）</button>
    </form>

    <h2>响应</h2>
    <pre>{{ output }}</pre>
  </div>
</template>

<style scoped>
.page {
  font-family: system-ui, sans-serif;
  max-width: 40rem;
  margin: 2rem auto;
  padding: 0 1rem;
}
label {
  display: block;
  margin-top: 0.75rem;
}
input[type="text"],
textarea {
  width: 100%;
  box-sizing: border-box;
  padding: 0.35rem;
}
button {
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  cursor: pointer;
}
pre {
  background: #f4f4f4;
  padding: 1rem;
  overflow: auto;
}
.hint {
  color: #666;
  font-size: 0.9rem;
}
</style>
