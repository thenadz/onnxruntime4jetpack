<p align="center">
  <img width="40%" src="docs/images/ONNX_Runtime_logo_dark.png" alt="ONNX Runtime" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img width="28%" src="docs/images/jetson_agx_xavier.jpg" alt="NVIDIA Jetson AGX Xavier" />
</p>

## Why This Fork?

NVIDIA's original Jetson lineup — Xavier, TX2, and Nano — remains widely deployed in production robotics, edge inference, and industrial automation. These modules are locked to **JetPack 5.x**, which ships **CUDA 11.4** and **nvcc 11.4**. NVIDIA does not provide newer CUDA toolkits for this hardware, and JetPack 6+ targets only the Orin generation.

Meanwhile, upstream ONNX Runtime has moved on. Newer releases assume CUDA 12+ features, use C++ constructs that trip nvcc 11.4 bugs, and reference FP8 data types that don't exist in CUDA 11.4 headers. The result: **ORT ≥ 1.17 will not build on JetPack 5.x without targeted patches**.

This fork bridges that gap. It carries a minimal, well-documented set of source-level fixes — applied on top of the official ORT v1.18 release — that restore compatibility with nvcc 11.4 and the JetPack 5.x SDK. Nothing is removed; the patches work around compiler limitations and missing constants so that the full CUDA and TensorRT execution providers build and run correctly on Xavier-class hardware.

**If you are running inference on a Jetson Xavier, TX2, or Nano module and need a current version of ONNX Runtime with GPU acceleration, this is the repo for you.**

**ONNX Runtime is a cross-platform inference and training machine-learning accelerator**.

**ONNX Runtime inference** can enable faster customer experiences and lower costs, supporting models from deep learning frameworks such as PyTorch and TensorFlow/Keras as well as classical machine learning libraries such as scikit-learn, LightGBM, XGBoost, etc. ONNX Runtime is compatible with different hardware, drivers, and operating systems, and provides optimal performance by leveraging hardware accelerators where applicable alongside graph optimizations and transforms. [Learn more &rarr;](https://www.onnxruntime.ai/docs/#onnx-runtime-for-inferencing)

**ONNX Runtime training** can accelerate the model training time on multi-node NVIDIA GPUs for transformer models with a one-line addition for existing PyTorch training scripts. [Learn more &rarr;](https://www.onnxruntime.ai/docs/#onnx-runtime-for-training)

## Get Started & Resources

* **General Information**: [onnxruntime.ai](https://onnxruntime.ai)

* **Usage documentation and tutorials**: [onnxruntime.ai/docs](https://onnxruntime.ai/docs)

* **YouTube video tutorials**: [youtube.com/@ONNXRuntime](https://www.youtube.com/@ONNXRuntime)

* [**Upcoming Release Roadmap**](https://github.com/microsoft/onnxruntime/wiki/Upcoming-Release-Roadmap)

* **Companion sample repositories**:
  - ONNX Runtime Inferencing: [microsoft/onnxruntime-inference-examples](https://github.com/microsoft/onnxruntime-inference-examples)
  - ONNX Runtime Training: [microsoft/onnxruntime-training-examples](https://github.com/microsoft/onnxruntime-training-examples)

## Builtin Pipeline Status

|System|Inference|Training|
|---|---|---|
|Windows|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Windows%20CPU%20CI%20Pipeline?label=Windows+CPU)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=9)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Windows%20GPU%20CI%20Pipeline?label=Windows+GPU)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=10)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Windows%20GPU%20TensorRT%20CI%20Pipeline?label=Windows+GPU+TensorRT)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=47)||
|Linux|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Linux%20CPU%20CI%20Pipeline?label=Linux+CPU)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=11)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Linux%20CPU%20Minimal%20Build%20E2E%20CI%20Pipeline?label=Linux+CPU+Minimal+Build)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=64)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Linux%20GPU%20CI%20Pipeline?label=Linux+GPU)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=12)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Linux%20GPU%20TensorRT%20CI%20Pipeline?label=Linux+GPU+TensorRT)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=45)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Linux%20OpenVINO%20CI%20Pipeline?label=Linux+OpenVINO)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=55)|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/orttraining-linux-ci-pipeline?label=Linux+CPU+Training)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=86)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/orttraining-linux-gpu-ci-pipeline?label=Linux+GPU+Training)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=84)<br>[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/orttraining/orttraining-ortmodule-distributed?label=Training+Distributed)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=148)|
|Mac|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/MacOS%20CI%20Pipeline?label=MacOS+CPU)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=13)||
|Android|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/Android%20CI%20Pipeline?label=Android)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=53)||
|iOS|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/iOS%20CI%20Pipeline?label=iOS)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=134)||
|Web|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/ONNX%20Runtime%20Web%20CI%20Pipeline?label=Web)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=161)||
|Other|[![Build Status](https://dev.azure.com/onnxruntime/onnxruntime/_apis/build/status/onnxruntime-binary-size-checks-ci-pipeline?repoName=microsoft%2Fonnxruntime&label=Binary+Size+Check)](https://dev.azure.com/onnxruntime/onnxruntime/_build/latest?definitionId=187&repoName=microsoft%2Fonnxruntime)||

## Third-party Pipeline Status

|System|Inference|Training|
|---|---|---|
|Linux|[![Build Status](https://github.com/Ascend/onnxruntime/actions/workflows/build-and-test.yaml/badge.svg)](https://github.com/Ascend/onnxruntime/actions/workflows/build-and-test.yaml)||

## Data/Telemetry

Windows distributions of this project may collect usage data and send it to Microsoft to help improve our products and services. See the [privacy statement](docs/Privacy.md) for more details.

## Contributions and Feedback

We welcome contributions! Please see the [contribution guidelines](CONTRIBUTING.md).

For feature requests or bug reports, please file a [GitHub Issue](https://github.com/Microsoft/onnxruntime/issues).

For general discussion or questions, please use [GitHub Discussions](https://github.com/microsoft/onnxruntime/discussions).

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## License

This project is licensed under the [MIT License](LICENSE).
