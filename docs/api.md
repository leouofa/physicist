# Physicist REST API (`/api/v1`) Specification & Developer Reference

This document provides a comprehensive technical reference for the programmatic REST API exposed by **Physicist** under `/api/v1`. The API is designed for external applications, researchers, and companion client environments (such as companion MCP servers or Python computational physics scripts) to query, manipulate, and orchestrate the entire particle physics catalog, vector embedding manifold, archetype clustering engine, and multi-stage LLM synthesis pipelines.

---

## 1. Architectural Overview & Conventions

### Base URL
```
http://localhost:3000/api/v1
```

### OpenAPI 3.1 Specification
Physicist serves an introspectable OpenAPI 3.1 JSON document directly at:
```http
GET /api/v1/openapi.json
```

### Response Envelopes
All responses are formatted as JSON using a consistent envelope structure:

#### Single Resource or Action Response
```json
{
  "data": { ... },
  "meta": { ... }
}
```

#### Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "total": 42,
    "limit": 50,
    "offset": 0
  }
}
```

#### Error Response
Standard HTTP status codes (`400 Bad Request`, `404 Not Found`, `422 Unprocessable Entity`, etc.) return an error object:
```json
{
  "error": {
    "code": "not_found",
    "message": "Couldn't find SubatomicParticle with 'id'=9999",
    "details": ["Optional validation errors or context"]
  }
}
```

### Pagination
Collection endpoints support `limit` (default: `50`, maximum: `500`) and `offset` (default: `0`) query parameters.

### Embedding Vectors (`pgvector` 1024-float arrays)
To keep network payloads lean, endpoints returning `SubatomicParticle` or `QuantumState` records include vector metadata (`embedded: boolean`, `embedding_model: string`, `embedded_at: timestamp`, `embedding_dimensions: 1024`), while the raw 1024-float array is omitted by default.
Pass `?include_embedding=true` on any individual or collection query to include the raw vector:
```json
{
  "data": {
    "id": 1,
    "name": "Up",
    "embedded": true,
    "embedding_model": "qwen3-embedding:0.6b",
    "embedding": [0.0123, -0.0456, 0.0891, ...]
  }
}
```

### Synchronous vs. Asynchronous Job Execution (`?sync=true`)
Long-running LLM and embedding operations (discovery, population, vector calculation) default to asynchronous execution via ActiveJob/Sidekiq (`202 Accepted` with `{ "data": { "job_id": "...", "status": "queued" } }`).
Clients can:
1. Poll the job status at `GET /api/v1/jobs/:id`.
2. Or pass `?sync=true` on single-entity actions (`POST /api/v1/subatomic_particles/:id/generate_embedding?sync=true`, `POST /api/v1/particle_groups/:id/populate_subatomic_particles?sync=true`, `POST /api/v1/subatomic_particles/:id/populate_quantum_states?sync=true`) to block until execution completes and receive the immediate result (`200 OK`).

---

## 2. Resource Endpoints

### 2.1 Particle Groups (`/api/v1/particle_groups`)

- `GET /api/v1/particle_groups`: List particle groups (supports `q`, `limit`, `offset`, `include_subatomic_particles`)
- `POST /api/v1/particle_groups`: Create a new particle group
- `GET /api/v1/particle_groups/:id`: Retrieve particle group by ID
- `PATCH /api/v1/particle_groups/:id`: Update particle group
- `DELETE /api/v1/particle_groups/:id`: Delete particle group
- `POST /api/v1/particle_groups/populate`: Trigger automated discovery of major particle groups
- `POST /api/v1/particle_groups/:id/populate_subatomic_particles`: Discover particles for a specific particle group
- `POST /api/v1/particle_groups/upsert_batch`: Bulk upsert particle group records

### 2.2 Subatomic Particles (`/api/v1/subatomic_particles`)

- `GET /api/v1/subatomic_particles`: List subatomic particles (supports `particle_group_id`, `theme`, `q`, `embedded`, `include_embedding`, `include_quantum_states`)
- `POST /api/v1/subatomic_particles`: Create a subatomic particle record
- `GET /api/v1/subatomic_particles/:id`: Retrieve particle details
- `PATCH /api/v1/subatomic_particles/:id`: Update particle details
- `DELETE /api/v1/subatomic_particles/:id`: Delete a particle
- `GET /api/v1/subatomic_particles/:id/neighbors`: Find nearest cosine-distance particle neighbors
- `POST /api/v1/subatomic_particles/:id/generate_embedding`: Generate or refresh 1024-d embedding vector
- `POST /api/v1/subatomic_particles/:id/populate_quantum_states`: Discover quantum states for this particle
- `POST /api/v1/subatomic_particles/populate`: Discover subatomic particles across all particle groups
- `POST /api/v1/subatomic_particles/upsert_batch`: Bulk upsert particles for a given `particle_group_id`
- `GET /api/v1/subatomic_particles/search`: Semantic vector and keyword search across particles

### 2.3 Quantum States (`/api/v1/quantum_states`)

- `GET /api/v1/quantum_states`: List quantum states (supports `subatomic_particle_id`, `particle_group_id`, `theme`, `q`, `embedded`, `include_embedding`)
- `POST /api/v1/quantum_states`: Create a quantum state record
- `GET /api/v1/quantum_states/:id`: Retrieve quantum state details
- `PATCH /api/v1/quantum_states/:id`: Update quantum state details
- `DELETE /api/v1/quantum_states/:id`: Delete a quantum state
- `GET /api/v1/quantum_states/:id/neighbors`: Find nearest quantum state counterparts
- `POST /api/v1/quantum_states/:id/generate_embedding`: Generate 1024-d embedding vector
- `POST /api/v1/quantum_states/populate`: Discover quantum states across all subatomic particles
- `POST /api/v1/quantum_states/upsert_batch`: Bulk upsert quantum states for a given `subatomic_particle_id`
- `GET /api/v1/quantum_states/search`: Semantic vector and keyword search across quantum states

### 2.4 Clustering & Snapshots (`/api/v1/clusters`, `/api/v1/cluster_snapshots`)

- `GET /api/v1/clusters`: Dynamically compute agglomerative clusters for `SubatomicParticle` or `QuantumState` across levels 1 to 15 (params: `target_type`, `level`, `full_coverage`, `force`)
- `GET /api/v1/cluster_snapshots`: List frozen cluster snapshots
- `POST /api/v1/clusters/snapshot`: Compute and persist a frozen cluster snapshot
- `GET /api/v1/cluster_snapshots/:id`: Retrieve snapshot details, clusters, and member records
- `DELETE /api/v1/cluster_snapshots/:id`: Delete snapshot

### 2.5 Multi-Stage AI Synthesis Reports (`/api/v1/cluster_reports`)

- `GET /api/v1/cluster_reports`: List synthesis reports
- `POST /api/v1/cluster_reports`: Run 2-phase Map-Reduce report on a saved snapshot
- `POST /api/v1/cluster_reports/:id/deep_synthesis`: Run 3-phase Hierarchical Deep Synthesis report
- `GET /api/v1/cluster_reports/:id`: Retrieve completed or running report details and synthesis monograph
- `DELETE /api/v1/cluster_reports/:id`: Delete report

### 2.6 Semantic Search & Discovery (`/api/v1/search`)

- `GET /api/v1/search`: Unified cross-entity search endpoint across subatomic particles and quantum states

### 2.7 Platform Status, Jobs & Settings (`/api/v1/status`, `/api/v1/settings`, `/api/v1/jobs`)

- `GET /api/v1/status`: Health check, database connectivity, `pgvector` version, Ollama reachability, counts of particle groups, subatomic particles, quantum states, and embeddings
- `GET /api/v1/settings`: Current LLM and embedding model configuration, context window sizes, temperature settings
- `PATCH /api/v1/settings/context_window`: Update runtime LLM context window size
- `POST /api/v1/settings/generate_embeddings`: Trigger background embedding generation for all un-embedded records
- `GET /api/v1/jobs`: List background jobs
- `GET /api/v1/jobs/:id`: Retrieve status of a queued or running job
