import argparse
from pathlib import Path

import onnx
import tensorflow as tf
from onnx_tf.backend import prepare


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    input_onnx = Path(args.input)
    output_tflite = Path(args.output)
    output_saved = output_tflite.with_suffix(".saved_model")
    output_tflite.parent.mkdir(parents=True, exist_ok=True)

    onnx_model = onnx.load(str(input_onnx))
    tf_rep = prepare(onnx_model)
    tf_rep.export_graph(str(output_saved))

    converter = tf.lite.TFLiteConverter.from_saved_model(str(output_saved))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_data = converter.convert()
    output_tflite.write_bytes(tflite_data)
    print(f"Converted: {output_tflite}")


if __name__ == "__main__":
    main()
