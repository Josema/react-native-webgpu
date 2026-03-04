import React from "react";
import { StyleSheet, View } from "react-native";
import { Canvas } from "react-native-wgpu";

import { useWebGPU } from "../components/useWebGPU";

import Common from "./common";
import Radiosity from "./radiosity";
import Rasterizer from "./rasterizer";
import Raytracer from "./raytracer";
import Scene from "./scene";
import Tonemapper from "./tonemapper";

export function Cornell() {
  const ref = useWebGPU(({ context, device, presentationFormat, canvas }) => {
    let outputFormat = presentationFormat;
    if (
      outputFormat === "bgra8unorm" &&
      !device.features.has("bgra8unorm-storage")
    ) {
      outputFormat = "rgba8unorm";
    }

    context.configure({
      device,
      format: outputFormat,
      alphaMode: "premultiplied",
    });

    const params: {
      renderer: "rasterizer" | "raytracer";
      rotateCamera: boolean;
    } = {
      renderer: "rasterizer",
      rotateCamera: true,
    };

    const framebuffer = device.createTexture({
      label: "Cornell.framebuffer",
      size: [canvas.width, canvas.height],
      format: "rgba16float",
      usage:
        GPUTextureUsage.RENDER_ATTACHMENT |
        GPUTextureUsage.STORAGE_BINDING |
        GPUTextureUsage.TEXTURE_BINDING,
    });

    const scene = new Scene(device);
    const common = new Common(device, scene.quadBuffer);
    const radiosity = new Radiosity(device, common, scene);
    const rasterizer = new Rasterizer(
      device,
      common,
      scene,
      radiosity,
      framebuffer
    );
    const raytracer = new Raytracer(device, common, radiosity, framebuffer);

    return () => {
      const canvasTexture = context.getCurrentTexture();
      const commandEncoder = device.createCommandEncoder();

      common.update({
        rotateCamera: params.rotateCamera,
        aspect: canvas.width / canvas.height,
      });
      radiosity.run(commandEncoder);

      switch (params.renderer) {
        case "rasterizer": {
          rasterizer.run(commandEncoder);
          break;
        }
        case "raytracer": {
          raytracer.run(commandEncoder);
          break;
        }
      }

      const tonemapper = new Tonemapper(
        device,
        framebuffer,
        canvasTexture
      );
      tonemapper.run(commandEncoder);

      device.queue.submit([commandEncoder.finish()]);
    };
  });

  return (
    <View style={styles.container}>
      <Canvas ref={ref} style={styles.canvas} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  canvas: {
    flex: 1,
  },
});
