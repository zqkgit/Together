import { computed, ref } from "vue";
import { defineStore } from "pinia";

export const useAppStore = defineStore("app", () => {
  const collapsed = ref(false);
  const userName = ref("平台运营");

  function toggleCollapsed() {
    collapsed.value = !collapsed.value;
  }

  const asideWidth = computed(() => (collapsed.value ? "72px" : "220px"));

  return {
    collapsed,
    userName,
    asideWidth,
    toggleCollapsed
  };
});
