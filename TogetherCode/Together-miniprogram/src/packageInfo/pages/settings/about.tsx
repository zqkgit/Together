import React from "react";
import { View, Text } from "@tarojs/components";
import "./about.scss";

export default function AboutPage() {
  return (
    <View className="about">
      <View className="about-icon">
        <Text className="about-icon-text">艺</Text>
      </View>
      <Text className="about-name">艺启</Text>
      <Text className="about-version">v1.0.0</Text>
      <Text className="about-slogan">让每个孩子都能遇见好的艺术启蒙</Text>
    </View>
  );
}