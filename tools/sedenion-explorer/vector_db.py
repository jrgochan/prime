from qdrant_client import QdrantClient
from qdrant_client.http.models import Distance, VectorParams, PointStruct
import uuid

class TopologyMemoryDB:
    def __init__(self, collection_name="rl_topology_states"):
        # Local scaffolding relies on RAM.
        # Hardware deployment targets the Rust native Qdrant instance
        self.client = QdrantClient(":memory:")
        self.collection_name = collection_name
        
        # Initialize the 16D Betti-Entropy vector collection framework
        collections_response = self.client.get_collections()
        exists = any(c.name == collection_name for c in collections_response.collections)
        
        if not exists:
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(size=16, distance=Distance.COSINE),
            )
            
    def commit_state(self, bivector_state: list[float], betti_reward: float) -> str:
        """Hashes the active hyper-geometry and permanently stores it in vector memory."""
        state_id = str(uuid.uuid4())
        self.client.upsert(
            collection_name=self.collection_name,
            points=[
                PointStruct(
                    id=state_id,
                    vector=bivector_state,
                    payload={"betti_score": betti_reward}
                )
            ]
        )
        return state_id
        
    def query_nearest_successful_state(self, current_stuck_state: list[float]):
        """
        Provides 'Memory' to the RL Agent.
        If the agent becomes trapped in a topological minimum during gradient descent,
        it queries this database to physically jump parameters to the nearest successful historical layout.
        """
        search_result = self.client.search(
            collection_name=self.collection_name,
            query_vector=current_stuck_state,
            query_filter=None, # Production: Filters for Payload.betti_score > Target
            limit=1
        )
        return search_result
