import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import onnxruntime as ort
from transformers import AutoTokenizer

# Load the tokenizer
MODEL_NAME = "antoinelouis/colbert-xm"
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

# Load the ONNX model
ONNX_MODEL_PATH = "colbert-xm.onnx"
ort_session = ort.InferenceSession(ONNX_MODEL_PATH)

def encode_text(text):
    """
    Encode a text (query or passage) into embeddings using the ONNX model.
    """
    # Tokenize the input text
    inputs = tokenizer(
        text,
        return_tensors="pt",
        padding=True,
        truncation=True,
        max_length=128,
    )
    input_ids = inputs["input_ids"].numpy().astype(np.int64)
    attention_mask = inputs["attention_mask"].numpy().astype(np.int64)

    # Run inference with ONNX
    embeddings = ort_session.run(
        None,
        {"input_ids": input_ids, "attention_mask": attention_mask},
    )[0]  # Shape: (1, sequence_length, 768)

    # Average the token embeddings to get a single vector representation
    return embeddings.mean(axis=1)  # Shape: (1, 768)

def compute_similarity(query_embedding, passage_embedding):
    """
    Compute the cosine similarity between the query and passage embeddings.
    """
    return cosine_similarity(query_embedding, passage_embedding)[0][0]

def main():
    # Example queries and passages
    queries = [
        "What is ColBERT?",
        "How does semantic search work?",
        "What is a neural search model?",
    ]
    passages = [
        "ColBERT is a neural search model that uses token-level embeddings for semantic search.",
        "Semantic search uses natural language processing to understand the meaning of queries and documents.",
        "A neural search model uses deep learning to improve search accuracy.",
    ]

    # Encode queries and passages
    print("Encoding queries and passages...")
    query_embeddings = [encode_text(query) for query in queries]
    passage_embeddings = [encode_text(passage) for passage in passages]

    # Compute similarities
    print("\nSimilarities:")
    for i, query_embedding in enumerate(query_embeddings):
        for j, passage_embedding in enumerate(passage_embeddings):
            similarity = compute_similarity(query_embedding, passage_embedding)
            print(f"Query {i+1} vs Passage {j+1}: {similarity:.4f}")

if __name__ == "__main__":
    main()
