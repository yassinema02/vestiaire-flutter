/**
 * URL scraper service for extracting product data from e-commerce pages.
 *
 * Extracts product metadata using three strategies:
 * 1. Open Graph meta tags (most common on e-commerce sites)
 * 2. JSON-LD schema.org Product markup (structured data)
 * 3. Raw HTML (trimmed to 10KB) for AI fallback extraction
 *
 * Uses regex-based extraction to avoid HTML parser dependencies.
 * No external dependencies -- uses Node.js built-in fetch.
 *
 * Story 8.1: Product URL Scraping (FR-SHP-02, FR-SHP-03)
 */

const FETCH_TIMEOUT_MS = 6000;
const RAW_HTML_LIMIT = 10 * 1024; // 10KB for AI fallback
const USER_AGENT = "Mozilla/5.0 (compatible; Vestiaire/1.0)";

/**
 * Validate that a URL is HTTPS with a valid hostname.
 */
function validateUrl(url) {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:") {
      return { valid: false, reason: "URL must use HTTPS" };
    }
    if (!parsed.hostname || parsed.hostname.length < 3) {
      return { valid: false, reason: "Invalid hostname" };
    }
    return { valid: true };
  } catch {
    return { valid: false, reason: "Malformed URL" };
  }
}

/**
 * Extract Open Graph meta tags from HTML using regex.
 *
 * Handles both property="og:..." content="..." and content="..." property="og:..." orderings.
 */
function extractOgTags(html) {
  const tags = {};

  const ogMappings = [
    { keys: ["og:title"], field: "title" },
    { keys: ["og:image"], field: "image" },
    { keys: ["og:description"], field: "description" },
    { keys: ["og:price:amount", "product:price:amount"], field: "price" },
    { keys: ["og:price:currency", "product:price:currency"], field: "currency" },
    { keys: ["og:brand", "product:brand"], field: "brand" },
  ];

  for (const mapping of ogMappings) {
    for (const key of mapping.keys) {
      // Match: <meta property="og:..." content="..."> (either order)
      const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const pattern1 = new RegExp(
        `<meta[^>]*property=["']${escapedKey}["'][^>]*content=["']([^"']*)["']`,
        "i"
      );
      const pattern2 = new RegExp(
        `<meta[^>]*content=["']([^"']*)["'][^>]*property=["']${escapedKey}["']`,
        "i"
      );

      const match = html.match(pattern1) || html.match(pattern2);
      if (match && match[1]) {
        tags[mapping.field] = match[1].trim();
        break; // Use first matching key variant
      }
    }
  }

  return tags;
}

/**
 * Extract JSON-LD Product data from script blocks.
 *
 * Finds <script type="application/ld+json"> blocks, parses JSON,
 * and locates objects with @type: "Product" (including nested in @graph arrays).
 */
function extractJsonLd(html) {
  const ldRegex = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  const results = [];

  while ((match = ldRegex.exec(html)) !== null) {
    try {
      const parsed = JSON.parse(match[1]);
      results.push(parsed);
    } catch {
      // Skip unparseable blocks
    }
  }

  // Find Product object in results
  for (const data of results) {
    const product = findProduct(data);
    if (product) {
      return extractProductFromJsonLd(product);
    }
  }

  return {};
}

/**
 * Recursively find a Product object in JSON-LD data.
 */
function findProduct(data) {
  if (!data) return null;

  if (data["@type"] === "Product") return data;

  // Check @graph array
  if (data["@graph"] && Array.isArray(data["@graph"])) {
    for (const item of data["@graph"]) {
      if (item["@type"] === "Product") return item;
    }
  }

  // Check if it's an array
  if (Array.isArray(data)) {
    for (const item of data) {
      const found = findProduct(item);
      if (found) return found;
    }
  }

  return null;
}

/**
 * Extract structured fields from a JSON-LD Product object.
 */
function extractProductFromJsonLd(product) {
  const result = {};

  if (product.name) result.name = product.name;

  if (product.image) {
    result.image = Array.isArray(product.image) ? product.image[0] : product.image;
    // Handle image objects with @type: ImageObject
    if (typeof result.image === "object" && result.image.url) {
      result.image = result.image.url;
    }
  }

  if (product.brand) {
    result.brand = typeof product.brand === "object" ? product.brand.name : product.brand;
  }

  if (product.offers) {
    const offers = Array.isArray(product.offers) ? product.offers[0] : product.offers;
    if (offers) {
      result.price = offers.price ?? offers.lowPrice ?? null;
      result.priceCurrency = offers.priceCurrency ?? null;
    }
  }

  if (product.description) result.description = product.description;
  if (product.color) result.color = product.color;
  if (product.material) result.material = product.material;

  return result;
}

/**
 * Determine the extraction method based on which sources had data.
 */
function determineExtractionMethod(ogTags, jsonLd) {
  const hasOg = Object.values(ogTags).some((v) => v != null && v !== "");
  const hasLd = Object.values(jsonLd).some((v) => v != null && v !== "");

  if (hasOg && hasLd) return "og_tags+json_ld";
  if (hasOg) return "og_tags";
  if (hasLd) return "json_ld";
  return "none";
}

/**
 * Create a URL scraper service instance.
 *
 * @returns {{ scrapeUrl: (url: string) => Promise<object> }}
 */
export function createUrlScraperService() {
  return {
    /**
     * Scrape a product URL for metadata.
     *
     * @param {string} url - HTTPS URL to scrape.
     * @returns {Promise<object>} Scraped data with ogTags, jsonLd, rawHtml, extractionMethod.
     */
    async scrapeUrl(url) {
      // (a) Validate URL
      const validation = validateUrl(url);
      if (!validation.valid) {
        return { error: "invalid_url", message: validation.reason };
      }

      // (b) Fetch the URL with timeout
      let html;
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

        const response = await fetch(url, {
          signal: controller.signal,
          headers: {
            "User-Agent": USER_AGENT,
            "Accept": "text/html",
          },
        });

        clearTimeout(timeout);

        if (!response.ok) {
          return { error: "http_error", statusCode: response.status };
        }

        html = await response.text();
      } catch (err) {
        if (err.name === "AbortError") {
          return { error: "timeout" };
        }
        return { error: "fetch_error", message: err.message };
      }

      // (c) & (d) Extract data
      const ogTags = extractOgTags(html);
      const jsonLd = extractJsonLd(html);
      const extractionMethod = determineExtractionMethod(ogTags, jsonLd);

      // (e) Return results
      return {
        ogTags,
        jsonLd,
        rawHtml: html.substring(0, RAW_HTML_LIMIT),
        extractionMethod,
      };
    },
  };
}

// Export internals for testing
export { validateUrl, extractOgTags, extractJsonLd, determineExtractionMethod };
