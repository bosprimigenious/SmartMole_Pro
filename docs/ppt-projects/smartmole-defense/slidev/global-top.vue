<template>
  <div class="bupt-header">
    <span class="bupt-logo">北邮 · BUPT</span>
    <span class="bupt-divider">|</span>
    <span class="bupt-title">SmartMole Pro · 第六组</span>
    <span class="bupt-motto">厚德博学 敬业乐群</span>
  </div>
</template>

<style scoped>
.bupt-header {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.45rem 1.5rem;
  font-size: 0.72rem;
  background: linear-gradient(90deg, rgba(0, 51, 153, 0.92), rgba(0, 51, 153, 0.55));
  border-bottom: 2px solid #d4a84b;
  backdrop-filter: blur(8px);
  color: #e8ecf1;
  pointer-events: none;
}
.bupt-logo {
  font-weight: 800;
  color: #fff;
  letter-spacing: 0.05em;
}
.bupt-divider { opacity: 0.4; }
.bupt-title { font-weight: 600; }
.bupt-motto {
  margin-left: auto;
  color: #00843d;
  font-weight: 600;
  opacity: 0.9;
}
</style>
