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
