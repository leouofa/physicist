# frozen_string_literal: true

module Api
  module V1
    class OpenapiSpec
      def self.generate
        {
          openapi: "3.1.0",
          info: {
            title: "Physicist Platform REST API",
            version: "1.0.0",
            description: "Full programmatic REST API for the Physicist computational laboratory for particle physics, subatomic particles, and quantum state manifolds."
          },
          servers: [
            { url: "/api/v1", description: "Default v1 endpoint" }
          ],
          paths: {
            "/status" => {
              get: {
                summary: "Platform status, health, and entity statistics",
                operationId: "getPlatformStatus",
                responses: {
                  "200" => { description: "Current platform status and counts" }
                }
              }
            },
            "/openapi.json" => {
              get: {
                summary: "OpenAPI 3.1 specification for Physicist",
                operationId: "getOpenapiSpec",
                responses: {
                  "200" => { description: "OpenAPI schema document" }
                }
              }
            },
            "/search" => {
              get: {
                summary: "Cross-resource semantic or keyword search across SubatomicParticles and QuantumStates",
                operationId: "searchAll",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[all subatomic_particle quantum_state], default: "all" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: {
                  "200" => { description: "Search results with similarity distances" }
                }
              }
            },
            "/particle_groups" => {
              get: {
                summary: "List particle_groups",
                operationId: "listParticleGroups",
                parameters: [
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "include_subatomic_particles", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of particle_groups" } }
              },
              post: {
                summary: "Create a particle_group",
                operationId: "createParticleGroup",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[name description],
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created particle_group" } }
              }
            },
            "/particle_groups/{id}" => {
              get: {
                summary: "Get particle_group details",
                operationId: "getParticleGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_subatomic_particles", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "ParticleGroup details" } }
              },
              patch: {
                summary: "Update particle_group",
                operationId: "updateParticleGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated particle_group" } }
              },
              delete: {
                summary: "Delete particle_group",
                operationId: "deleteParticleGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "ParticleGroup deleted" } }
              }
            },
            "/particle_groups/upsert_batch" => {
              post: {
                summary: "Batch upsert particle_groups",
                operationId: "batchUpsertParticleGroups",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[particle_groups],
                        properties: {
                          particle_groups: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted particle_groups" } }
              }
            },
            "/particle_groups/populate" => {
              post: {
                summary: "Trigger LLM discovery of particle_groups",
                operationId: "populateParticleGroups",
                parameters: [
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/particle_groups/{id}/populate_subatomic_particles" => {
              post: {
                summary: "Trigger LLM discovery of subatomic_particles for a single particle_group",
                operationId: "populateParticleGroupSubatomicParticles",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/subatomic_particles" => {
              get: {
                summary: "List/filter subatomic_particles",
                operationId: "listSubatomicParticles",
                parameters: [
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "particle_group", in: "query", required: false, schema: { type: "string" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_quantum_states", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of subatomic_particles" } }
              },
              post: {
                summary: "Create a subatomic_particle",
                operationId: "createSubatomicParticle",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[particle_group_id name description],
                        properties: {
                          particle_group_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created subatomic_particle" } }
              }
            },
            "/subatomic_particles/search" => {
              get: {
                summary: "Semantic or keyword search for subatomic_particles",
                operationId: "searchSubatomicParticles",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "SubatomicParticle search results" } }
              }
            },
            "/subatomic_particles/{id}" => {
              get: {
                summary: "Get subatomic_particle details",
                operationId: "getSubatomicParticle",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_quantum_states", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "SubatomicParticle details" } }
              },
              patch: {
                summary: "Update subatomic_particle",
                operationId: "updateSubatomicParticle",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } },
                          particle_group_id: { type: "integer" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated subatomic_particle" } }
              },
              delete: {
                summary: "Delete subatomic_particle",
                operationId: "deleteSubatomicParticle",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "SubatomicParticle deleted" } }
              }
            },
            "/subatomic_particles/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor subatomic_particles by cosine distance",
                operationId: "getSubatomicParticleNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/subatomic_particles/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for subatomic_particle",
                operationId: "generateSubatomicParticleEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/subatomic_particles/{id}/populate_quantum_states" => {
              post: {
                summary: "Discover/populate quantum_states for a subatomic_particle via LLM",
                operationId: "populateSubatomicParticleQuantumStates",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Quantum states created" }, "202" => { description: "Job queued" } }
              }
            },
            "/subatomic_particles/populate" => {
              post: {
                summary: "Trigger bulk LLM subatomic_particle discovery",
                operationId: "populateAllSubatomicParticles",
                parameters: [
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/subatomic_particles/upsert_batch" => {
              post: {
                summary: "Batch upsert subatomic_particles for a particle_group",
                operationId: "batchUpsertSubatomicParticles",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[particle_group_id subatomic_particles],
                        properties: {
                          particle_group_id: { type: "integer" },
                          subatomic_particles: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted subatomic_particles" } }
              }
            },
            "/quantum_states" => {
              get: {
                summary: "List/filter quantum_states",
                operationId: "listQuantumStates",
                parameters: [
                  { name: "subatomic_particle_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of quantum_states" } }
              },
              post: {
                summary: "Create a quantum_state for a subatomic_particle",
                operationId: "createQuantumState",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[subatomic_particle_id name description],
                        properties: {
                          subatomic_particle_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created quantum_state" } }
              }
            },
            "/quantum_states/search" => {
              get: {
                summary: "Semantic or keyword search for quantum_states",
                operationId: "searchQuantumStates",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "subatomic_particle_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "QuantumState search results" } }
              }
            },
            "/quantum_states/{id}" => {
              get: {
                summary: "Get quantum_state details",
                operationId: "getQuantumState",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "QuantumState details" } }
              },
              patch: {
                summary: "Update quantum_state",
                operationId: "updateQuantumState",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated quantum_state" } }
              },
              delete: {
                summary: "Delete quantum_state",
                operationId: "deleteQuantumState",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "QuantumState deleted" } }
              }
            },
            "/quantum_states/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor quantum_states by cosine distance",
                operationId: "getQuantumStateNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "subatomic_particle_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "particle_group_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/quantum_states/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for quantum_state",
                operationId: "generateQuantumStateEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/quantum_states/populate" => {
              post: {
                summary: "Trigger bulk LLM quantum_state discovery",
                operationId: "populateAllQuantumStates",
                parameters: [
                  { name: "subatomic_particle_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/quantum_states/upsert_batch" => {
              post: {
                summary: "Batch upsert quantum_states for a subatomic_particle",
                operationId: "batchUpsertQuantumStates",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[subatomic_particle_id quantum_states],
                        properties: {
                          subatomic_particle_id: { type: "integer" },
                          quantum_states: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted quantum_states" } }
              }
            },
            "/clusters" => {
              get: {
                summary: "Compute or fetch live clusters",
                operationId: "getLiveClusters",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[SubatomicParticle QuantumState], default: "SubatomicParticle" } },
                  { name: "level", in: "query", required: false, schema: { type: "integer", minimum: 1, maximum: 15, default: 5 } },
                  { name: "full_coverage", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "force", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Clustering result" } }
              }
            },
            "/clusters/snapshot" => {
              post: {
                summary: "Compute and save a cluster snapshot",
                operationId: "createSnapshotFromCluster",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[SubatomicParticle QuantumState], default: "SubatomicParticle" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Persisted ClusterSnapshot" } }
              }
            },
            "/cluster_snapshots" => {
              get: {
                summary: "List cluster snapshots",
                operationId: "listClusterSnapshots",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[SubatomicParticle QuantumState] } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of snapshots" } }
              },
              post: {
                summary: "Create and persist a snapshot",
                operationId: "createClusterSnapshot",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[SubatomicParticle QuantumState], default: "SubatomicParticle" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created snapshot" } }
              }
            },
            "/cluster_snapshots/{id}" => {
              get: {
                summary: "Get cluster snapshot details with groups",
                operationId: "getClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_groups", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_reports", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Snapshot details" } }
              },
              delete: {
                summary: "Delete cluster snapshot",
                operationId: "deleteClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Snapshot deleted" } }
              }
            },
            "/cluster_snapshots/{cluster_snapshot_id}/cluster_groups" => {
              get: {
                summary: "List cluster groups in a snapshot",
                operationId: "listSnapshotGroups",
                parameters: [
                  { name: "cluster_snapshot_id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "List of cluster groups" } }
              }
            },
            "/cluster_groups/{id}" => {
              get: {
                summary: "Get cluster group details with members",
                operationId: "getClusterGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cluster group details" } }
              }
            },
            "/cluster_reports" => {
              get: {
                summary: "List cluster reports",
                operationId: "listClusterReports",
                parameters: [
                  { name: "cluster_snapshot_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[SubatomicParticle QuantumState] } },
                  { name: "status", in: "query", required: false, schema: { type: "string" } },
                  { name: "is_detailed", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of cluster reports" } }
              },
              post: {
                summary: "Create a cluster synthesis report",
                operationId: "createClusterReport",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[cluster_snapshot_id],
                        properties: {
                          cluster_snapshot_id: { type: "integer" },
                          prompt: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created report" } }
              }
            },
            "/cluster_reports/{id}" => {
              get: {
                summary: "Get cluster report details",
                operationId: "getClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_summaries", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_sub_reports", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Cluster report details" } }
              },
              delete: {
                summary: "Delete cluster report",
                operationId: "deleteClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Report deleted" } }
              }
            },
            "/cluster_reports/{id}/deep_synthesis" => {
              post: {
                summary: "Create detailed 3-phase report from an existing report",
                operationId: "createDeepSynthesisReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          batch_size: { type: "integer", minimum: 2, maximum: 50, default: 5 }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created deep synthesis report" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/summaries" => {
              get: {
                summary: "List Phase 1 per-cluster summaries",
                operationId: "listReportSummaries",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of summaries" } }
              }
            },
            "/cluster_report_summaries/{id}" => {
              get: {
                summary: "Get a single cluster report summary",
                operationId: "getReportSummary",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Summary details" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/sub_reports" => {
              get: {
                summary: "List Phase 2 batch sub-reports",
                operationId: "listReportSubReports",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of sub-reports" } }
              }
            },
            "/cluster_sub_reports/{id}" => {
              get: {
                summary: "Get a single batch sub-report",
                operationId: "getReportSubReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Sub-report details" } }
              }
            },
            "/jobs" => {
              get: {
                summary: "List recent background jobs",
                operationId: "listJobs",
                parameters: [
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Recent jobs" } }
              }
            },
            "/jobs/{id}" => {
              get: {
                summary: "Get status and progress of a background job",
                operationId: "getJobStatus",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "string" } }
                ],
                responses: { "200" => { description: "Job status" } }
              }
            },
            "/settings" => {
              get: {
                summary: "Get platform embedding and LLM settings",
                operationId: "getSettings",
                responses: { "200" => { description: "Settings and statistics" } }
              }
            },
            "/settings/context_window" => {
              patch: {
                summary: "Update LLM context window",
                operationId: "updateContextWindow",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[context_window],
                        properties: {
                          context_window: { type: "integer", minimum: 4096 }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated context window" } }
              }
            },
            "/settings/generate_embeddings" => {
              post: {
                summary: "Enqueue bulk embedding generation",
                operationId: "generateAllEmbeddings",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[model_type],
                        properties: {
                          model_type: { type: "string", enum: %w[SubatomicParticle QuantumState] },
                          only_missing: { type: "boolean", default: true }
                        }
                      }
                    }
                  }
                },
                responses: { "202" => { description: "Job enqueued" } }
              }
            }
          }
        }
      end
    end
  end
end
