/**
 * Thin wrapper around @google-cloud/vertexai that initializes the Vertex AI
 * client and provides access to Gemini models.
 *
 * This is the single AI client for ALL AI features in the application.
 * Future stories (categorization, outfit generation, etc.) will reuse this client.
 */

/**
 * Creates a Gemini client synchronously with lazy initialization.
 * The VertexAI SDK is loaded on first use of getGenerativeModel.
 *
 * @param {object} options
 * @param {string} options.gcpProjectId - Google Cloud project ID.
 * @param {string} options.vertexAiLocation - Vertex AI region (e.g. "europe-west1").
 * @returns {{ getGenerativeModel: (modelName: string) => Promise<object>, isAvailable: () => boolean }}
 */
export function createGeminiClientSync({ gcpProjectId, vertexAiLocation }) {
  if (!gcpProjectId) {
    console.warn(
      "[gemini-client] GCP_PROJECT_ID not set. AI features will be disabled (graceful degradation)."
    );
    return {
      isAvailable() {
        return false;
      },
      async getGenerativeModel() {
        throw new Error("Gemini client is not available: GCP_PROJECT_ID not configured");
      }
    };
  }

  let vertexAI = null;
  let initPromise = null;

  async function ensureInitialized() {
    if (vertexAI) return;
    if (!initPromise) {
      initPromise = import("@google-cloud/vertexai").then(({ VertexAI }) => {
        vertexAI = new VertexAI({ project: gcpProjectId, location: vertexAiLocation });
      });
    }
    await initPromise;
  }

  return {
    isAvailable() {
      return true;
    },

    async getGenerativeModel(modelName) {
      await ensureInitialized();
      return vertexAI.getGenerativeModel({ model: modelName });
    }
  };
}
