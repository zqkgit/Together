<script setup lang="ts">
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import { Lock, User } from "@element-plus/icons-vue";
import { useAuthStore, type LoginScope } from "../../stores/auth";

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const scope = ref<LoginScope>("platform");
const username = ref("");
const password = ref("");
const loading = ref(false);

const demoAccounts: Record<LoginScope, { username: string; password: string; label: string }> = {
  platform: { username: "platform_admin", password: "123456", label: "平台超管" },
  studio: { username: "studio_owner_1", password: "123456", label: "工作室主理人" }
};

function switchScope(next: LoginScope) {
  scope.value = next;
  const demo = demoAccounts[next];
  username.value = demo.username;
  password.value = demo.password;
}

function fillDemo() {
  const demo = demoAccounts[scope.value];
  username.value = demo.username;
  password.value = demo.password;
}

async function handleLogin() {
  if (!username.value.trim() || !password.value) {
    ElMessage.warning("请输入账号和密码");
    return;
  }
  loading.value = true;
  try {
    await authStore.login(scope.value, username.value.trim(), password.value);
    ElMessage.success("登录成功，欢迎回来");
    const redirect = typeof route.query.redirect === "string" ? route.query.redirect : "/";
    router.push(redirect);
  } catch {
    // 错误提示已由 request 拦截器统一处理
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="login-page">
    <section class="brand-panel">
      <div class="brand-inner">
        <div class="brand-logo">
          <span class="logo-mark">艺</span>
          <div class="logo-copy">
            <strong>艺启</strong>
            <span>YIQI · 儿童艺术教育平台</span>
          </div>
        </div>

        <h1 class="brand-title">让每一次创作<br />都被看见</h1>
        <p class="brand-sub">
          家长购课 · 老师记录 · 工作室经营<br />
          一个平台连接孩子成长路上的每个人
        </p>

        <ul class="brand-points">
          <li><span class="point-dot"></span>工作室认证入驻与生命周期管理</li>
          <li><span class="point-dot"></span>全平台经营数据实时看板</li>
          <li><span class="point-dot"></span>结算分账与抽成对账闭环</li>
        </ul>

        <div class="brand-foot">Together Admin Console</div>
      </div>
    </section>

    <section class="form-panel">
      <div class="form-card">
        <div class="form-head">
          <h2>欢迎回来</h2>
          <p>登录「艺启」管理控制台</p>
        </div>

        <div class="scope-tabs">
          <button
            type="button"
            :class="['scope-tab', { active: scope === 'platform' }]"
            @click="switchScope('platform')"
          >
            平台后台
          </button>
          <button
            type="button"
            :class="['scope-tab', { active: scope === 'studio' }]"
            @click="switchScope('studio')"
          >
            工作室后台
          </button>
        </div>

        <form @submit.prevent="handleLogin">
          <el-input
            v-model="username"
            class="form-input"
            size="large"
            placeholder="账号"
            :prefix-icon="User"
            autocomplete="username"
          />
          <el-input
            v-model="password"
            class="form-input"
            size="large"
            type="password"
            placeholder="密码"
            :prefix-icon="Lock"
            show-password
            autocomplete="current-password"
            @keyup.enter="handleLogin"
          />

          <el-button
            type="primary"
            class="submit-btn"
            size="large"
            :loading="loading"
            @click="handleLogin"
          >
            {{ scope === "platform" ? "进入平台后台" : "进入工作室后台" }}
          </el-button>
        </form>

        <div class="demo-tip" @click="fillDemo">
          <span class="demo-label">演示账号</span>
          <code>{{ demoAccounts[scope].label }}：{{ demoAccounts[scope].username }} / {{ demoAccounts[scope].password }}</code>
          <span class="demo-action">点击填入</span>
        </div>
      </div>

      <p class="form-foot">© 2026 艺启 YIQI · 温暖手作设计系统 v2</p>
    </section>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: grid;
  grid-template-columns: minmax(0, 5fr) minmax(0, 7fr);
  background: #faf7f1;
}

/* ============ 左：品牌区 ============ */
.brand-panel {
  background: linear-gradient(160deg, #22422f 0%, #2f5d45 68%, #3a6b52 100%);
  color: #f5f0e6;
  display: flex;
  align-items: center;
  padding: 56px;
  position: relative;
  overflow: hidden;
}

.brand-panel::after {
  content: "";
  position: absolute;
  right: -120px;
  bottom: -120px;
  width: 340px;
  height: 340px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(168, 122, 62, 0.28) 0%, transparent 68%);
}

.brand-inner {
  position: relative;
  z-index: 1;
  max-width: 440px;
}

.brand-logo {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 56px;
}

.logo-mark {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  background: #a87a3e;
  color: #fff;
  display: grid;
  place-items: center;
  font-size: 26px;
  font-weight: 700;
  font-family: "Noto Serif SC", "Songti SC", serif;
  box-shadow: 0 4px 16px rgba(140, 89, 46, 0.35);
}

.logo-copy {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.logo-copy strong {
  font-family: "Noto Serif SC", "Songti SC", serif;
  font-size: 22px;
  letter-spacing: 2px;
}

.logo-copy span {
  font-size: 12px;
  color: #a9bca2;
  letter-spacing: 1px;
}

.brand-title {
  font-family: "Noto Serif SC", "Songti SC", serif;
  font-size: 40px;
  font-weight: 700;
  line-height: 1.3;
  margin: 0 0 20px;
  color: #f5f0e6;
}

.brand-sub {
  font-size: 15px;
  line-height: 1.8;
  color: #a9bca2;
  margin: 0 0 44px;
}

.brand-points {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 16px;
  font-size: 14px;
  color: #f5f0e6;
}

.brand-points li {
  display: flex;
  align-items: center;
  gap: 10px;
}

.point-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #c15f2c;
  flex-shrink: 0;
}

.brand-foot {
  margin-top: 64px;
  font-size: 12px;
  letter-spacing: 3px;
  color: rgba(245, 240, 230, 0.5);
  text-transform: uppercase;
}

/* ============ 右：表单区 ============ */
.form-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 48px 24px;
  gap: 24px;
}

.form-card {
  width: 100%;
  max-width: 420px;
  background: #ffffff;
  border: 1px solid #e6dfd3;
  border-radius: 16px;
  padding: 40px 36px;
  box-shadow:
    0 4px 16px rgba(43, 38, 33, 0.05),
    0 2px 6px rgba(43, 38, 33, 0.03);
}

.form-head h2 {
  margin: 0 0 6px;
  font-family: "Noto Serif SC", "Songti SC", serif;
  font-size: 26px;
  color: #2b2621;
}

.form-head p {
  margin: 0 0 28px;
  font-size: 14px;
  color: #726a60;
}

.scope-tabs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4px;
  background: #f4efe6;
  border-radius: 9999px;
  padding: 4px;
  margin-bottom: 24px;
}

.scope-tab {
  border: none;
  background: transparent;
  border-radius: 9999px;
  padding: 10px 0;
  font-size: 14px;
  font-weight: 600;
  color: #726a60;
  cursor: pointer;
  transition: all 0.2s ease;
}

.scope-tab.active {
  background: #2f5d45;
  color: #f5f0e6;
  box-shadow: 0 4px 12px rgba(47, 93, 69, 0.25);
}

.form-input {
  margin-bottom: 16px;
}

.form-input :deep(.el-input__wrapper) {
  border-radius: 12px;
  box-shadow: 0 0 0 1px #e6dfd3 inset;
  padding: 4px 14px;
  background: #fff;
}

.form-input :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 1.5px #2f5d45 inset;
}

.submit-btn {
  width: 100%;
  margin-top: 8px;
  height: 48px;
  border-radius: 12px;
  font-size: 15px;
  font-weight: 600;
  background: #2f5d45;
  border-color: #2f5d45;
  box-shadow: 0 4px 14px rgba(47, 93, 69, 0.3);
}

.submit-btn:hover {
  background: #22422f;
  border-color: #22422f;
}

.demo-tip {
  margin-top: 22px;
  padding: 12px 14px;
  background: #f4efe6;
  border: 1px dashed #d8cdbb;
  border-radius: 10px;
  font-size: 12px;
  color: #726a60;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  cursor: pointer;
  transition: background 0.2s ease;
}

.demo-tip:hover {
  background: #efe8da;
}

.demo-label {
  color: #a87a3e;
  font-weight: 600;
}

.demo-tip code {
  font-size: 12px;
  color: #2b2621;
}

.demo-action {
  margin-left: auto;
  color: #2f5d45;
  font-weight: 600;
}

.form-foot {
  margin: 0;
  font-size: 12px;
  color: #9c9385;
  letter-spacing: 0.5px;
}

/* ============ 响应式 ============ */
@media (max-width: 900px) {
  .login-page {
    grid-template-columns: 1fr;
  }

  .brand-panel {
    display: none;
  }

  .form-panel {
    padding: 32px 16px;
  }
}
</style>
