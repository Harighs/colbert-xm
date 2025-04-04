curl -X POST "http://localhost:8000/v2/models/colbert_xm/infer" \
     -H "Content-Type: application/json" \
     -d '{
       "inputs": [
         {
           "name": "input_ids",
           "shape": [1, 10], 
           "datatype": "INT64",
           "data": [[101, 2023, 2003, 1037, 3793, 9432, 4011, 2125, 102, 0]]
         },
         {
           "name": "attention_mask",
           "shape": [1, 10], 
           "datatype": "INT64",
           "data": [[1, 1, 1, 1, 1, 1, 1, 1, 0, 0]]
         }
       ]
     }'


Survey:
1. [2405.17935 (arxiv.org)](https://arxiv.org/pdf/2405.17935)
2. [2303.18223 (arxiv.org)](https://arxiv.org/pdf/2303.18223)
4. [Toolformer (arxiv.org)](https://arxiv.org/pdf/2302.04761)
5. [2112.04426 (arxiv.org)](https://arxiv.org/pdf/2112.04426)
6. [2005.11401 (arxiv.org)](https://arxiv.org/pdf/2005.11401)
7. [2002.08909 (arxiv.org)](https://arxiv.org/pdf/2002.08909)
