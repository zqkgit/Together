import React, { useEffect } from "react";
import Taro from "@tarojs/taro";
import "./app.scss";
import { useAuthStore } from "./store/auth";

function App(props) {
  const hydrate = useAuthStore((s) => s.hydrate);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const hydrated = useAuthStore((s) => s.hydrated);

  useEffect(() => {
    hydrate();
  }, []);

  // 全局登录守卫：hydrate 完成后，未登录则跳转登录页
  useEffect(() => {
    if (hydrated && !isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
    }
  }, [hydrated, isLoggedIn]);

  return props.children;
}

export default App;
