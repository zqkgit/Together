import React, { useEffect } from "react";
import Taro from "@tarojs/taro";
import "./app.scss";
import { useAuthStore } from "./store/auth";

function App(props) {
  const hydrate = useAuthStore((s) => s.hydrate);

  useEffect(() => {
    hydrate();
  }, []);

  return props.children;
}

export default App;
