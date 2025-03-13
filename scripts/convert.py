import torch
import numpy as np
import onnxruntime as ort
from transformers import AutoTokenizer, AutoModel

# Model name from Hugging Face
MODEL_NAME = "antoinelouis/colbert-xm"
ONNX_MODEL_PATH = "colbert-xm.onnx"

class ColBERTXMModelWithoutLangAdapter(torch.nn.Module):
    """
    A custom version of the ColBERT-XM model that bypasses the language-specific adapters.
    """
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        # Directly use the XmodModel's forward pass
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        return outputs.last_hidden_state

def download_model():
    """Download the ColBERT-XM model and tokenizer from Hugging Face."""
    print("Downloading model and tokenizer...")
    model = AutoModel.from_pretrained(MODEL_NAME)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    return model, tokenizer

def convert_to_onnx(model, tokenizer):
    """Convert the ColBERT-XM model to ONNX format."""
    print("Converting model to ONNX...")

    # Wrap the model to bypass language-specific adapters
    print("Wrapping model to bypass language adapters...")
    model_without_lang_adapter = ColBERTXMModelWithoutLangAdapter(model)

    # Create a dummy input using the tokenizer
    dummy_input = tokenizer(
        "This is a sample input for ColBERT-XM",
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=128,
    )
    input_ids = dummy_input["input_ids"]
    attention_mask = dummy_input["attention_mask"]

    # Export the model
    torch.onnx.export(
        model_without_lang_adapter,
        (input_ids, attention_mask),
        ONNX_MODEL_PATH,
        export_params=True,
        opset_version=12,
        input_names=["input_ids", "attention_mask"],
        output_names=["last_hidden_state"],
        dynamic_axes={
            "input_ids": {0: "batch_size", 1: "sequence_length"},
            "attention_mask": {0: "batch_size", 1: "sequence_length"},
            "last_hidden_state": {0: "batch_size", 1: "sequence_length"},
        },
    )

    print(f"ONNX model saved to {ONNX_MODEL_PATH}")

def validate_onnx(tokenizer):
    """Validate the ONNX model using ONNX Runtime."""
    print("Validating ONNX model...")

    # Load ONNX model
    ort_session = ort.InferenceSession(ONNX_MODEL_PATH)

    # Prepare a dummy input using the tokenizer
    dummy_input = tokenizer(
        "This is a validation input for ColBERT-XM",
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=128,
    )
    input_ids = dummy_input["input_ids"].numpy().astype(np.int64)
    attention_mask = dummy_input["attention_mask"].numpy().astype(np.int64)

    # Run inference
    outputs = ort_session.run(
        None,
        {"input_ids": input_ids, "attention_mask": attention_mask},
    )
    print("ONNX model output shape:", outputs[0].shape)

if __name__ == "__main__":
    model, tokenizer = download_model()
    convert_to_onnx(model, tokenizer)
    validate_onnx(tokenizer)
