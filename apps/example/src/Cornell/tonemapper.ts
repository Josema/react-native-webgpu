import { tonemapperWGSL } from './Shaders';

/**
 * Tonemapper implements a tonemapper to convert a linear-light framebuffer to
 * a gamma-correct, tonemapped framebuffer used for presentation.
 */
export default class Tonemapper {
  private readonly bindGroup: GPUBindGroup;
  private readonly pipeline: GPURenderPipeline;
  private readonly renderPassDescriptor: GPURenderPassDescriptor;

  constructor(
    device: GPUDevice,
    input: GPUTexture,
    output: GPUTexture
  ) {
    const bindGroupLayout = device.createBindGroupLayout({
      label: 'Tonemapper.bindGroupLayout',
      entries: [
        {
          // input
          binding: 0,
          visibility: GPUShaderStage.FRAGMENT,
          texture: {
            viewDimension: '2d',
          },
        },
        {
          // sampler
          binding: 1,
          visibility: GPUShaderStage.FRAGMENT,
          sampler: {},
        },
      ],
    });
    this.bindGroup = device.createBindGroup({
      label: 'Tonemapper.bindGroup',
      layout: bindGroupLayout,
      entries: [
        {
          // input
          binding: 0,
          resource: input.createView(),
        },
        {
          // sampler
          binding: 1,
          resource: device.createSampler({
            magFilter: 'linear',
            minFilter: 'linear',
            addressModeU: 'clamp-to-edge',
            addressModeV: 'clamp-to-edge',
          }),
        },
      ],
    });

    const mod = device.createShaderModule({
      code: tonemapperWGSL,
    });
    const pipelineLayout = device.createPipelineLayout({
      label: 'Tonemap.pipelineLayout',
      bindGroupLayouts: [bindGroupLayout],
    });

    this.pipeline = device.createRenderPipeline({
      label: 'Tonemap.pipeline',
      layout: pipelineLayout,
      vertex: {
        module: mod,
        entryPoint: 'vs_main',
      },
      fragment: {
        module: mod,
        entryPoint: 'fs_main',
        targets: [{ format: output.format }],
      },
      primitive: {
        topology: 'triangle-list',
      },
    });

    this.renderPassDescriptor = {
      colorAttachments: [
        {
          view: output.createView(),
          loadOp: 'clear',
          storeOp: 'store',
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    };
  }

  run(commandEncoder: GPUCommandEncoder) {
    const passEncoder = commandEncoder.beginRenderPass(this.renderPassDescriptor);
    passEncoder.setBindGroup(0, this.bindGroup);
    passEncoder.setPipeline(this.pipeline);
    passEncoder.draw(3);
    passEncoder.end();
  }
}
