import argparse
from pathlib import Path

import torch


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    input_pt = Path(args.input)
    output_onnx = Path(args.output)
    output_onnx.parent.mkdir(parents=True, exist_ok=True)

    model = torch.jit.load(str(input_pt), map_location="cpu")
    model.eval()
    dummy = torch.randn(1, 3, 224, 224, dtype=torch.float32)

    torch.onnx.export(
        model,
        dummy,
        str(output_onnx),
        input_names=["input"],
        output_names=["output"],
        opset_version=13,
        dynamic_axes=None,
        dynamo=False,
    )
    print(f"Exported: {output_onnx}")


if __name__ == "__main__":
    main()
