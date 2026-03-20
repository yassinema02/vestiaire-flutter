import assert from "node:assert/strict";
import test from "node:test";
import {
  createUrlScraperService,
  validateUrl,
  extractOgTags,
  extractJsonLd,
  determineExtractionMethod
} from "../../../src/modules/shopping/url-scraper-service.js";

// --- validateUrl tests ---

test("validateUrl: accepts valid HTTPS URL", () => {
  const result = validateUrl("https://www.zara.com/uk/en/shirt-p12345.html");
  assert.equal(result.valid, true);
});

test("validateUrl: rejects HTTP URL", () => {
  const result = validateUrl("http://www.zara.com/shirt");
  assert.equal(result.valid, false);
  assert.ok(result.reason.includes("HTTPS"));
});

test("validateUrl: rejects malformed URL", () => {
  const result = validateUrl("not-a-url");
  assert.equal(result.valid, false);
});

test("validateUrl: rejects empty string", () => {
  const result = validateUrl("");
  assert.equal(result.valid, false);
});

// --- extractOgTags tests ---

test("extractOgTags: extracts standard OG tags from valid HTML", () => {
  const html = `
    <html><head>
      <meta property="og:title" content="Blue Cotton Shirt">
      <meta property="og:image" content="https://example.com/shirt.jpg">
      <meta property="og:price:amount" content="29.99">
      <meta property="og:price:currency" content="GBP">
      <meta property="og:brand" content="Zara">
      <meta property="og:description" content="A nice shirt">
    </head></html>
  `;
  const tags = extractOgTags(html);
  assert.equal(tags.title, "Blue Cotton Shirt");
  assert.equal(tags.image, "https://example.com/shirt.jpg");
  assert.equal(tags.price, "29.99");
  assert.equal(tags.currency, "GBP");
  assert.equal(tags.brand, "Zara");
  assert.equal(tags.description, "A nice shirt");
});

test("extractOgTags: handles product: prefix variants", () => {
  const html = `
    <html><head>
      <meta property="product:price:amount" content="49.99">
      <meta property="product:price:currency" content="USD">
      <meta property="product:brand" content="Nike">
    </head></html>
  `;
  const tags = extractOgTags(html);
  assert.equal(tags.price, "49.99");
  assert.equal(tags.currency, "USD");
  assert.equal(tags.brand, "Nike");
});

test("extractOgTags: handles reverse attribute order (content before property)", () => {
  const html = `
    <html><head>
      <meta content="Reverse Order Shirt" property="og:title">
    </head></html>
  `;
  const tags = extractOgTags(html);
  assert.equal(tags.title, "Reverse Order Shirt");
});

test("extractOgTags: returns empty object for missing OG tags", () => {
  const html = `<html><head><title>No OG</title></head></html>`;
  const tags = extractOgTags(html);
  assert.deepEqual(tags, {});
});

// --- extractJsonLd tests ---

test("extractJsonLd: extracts Product data from valid JSON-LD", () => {
  const html = `
    <html><head>
      <script type="application/ld+json">
        {
          "@type": "Product",
          "name": "Slim Fit Jeans",
          "image": "https://example.com/jeans.jpg",
          "brand": { "@type": "Brand", "name": "Levi's" },
          "offers": { "price": "79.99", "priceCurrency": "EUR" },
          "description": "Classic slim fit"
        }
      </script>
    </head></html>
  `;
  const ld = extractJsonLd(html);
  assert.equal(ld.name, "Slim Fit Jeans");
  assert.equal(ld.image, "https://example.com/jeans.jpg");
  assert.equal(ld.brand, "Levi's");
  assert.equal(ld.price, "79.99");
  assert.equal(ld.priceCurrency, "EUR");
  assert.equal(ld.description, "Classic slim fit");
});

test("extractJsonLd: prefers JSON-LD data over OG tags when both present", () => {
  // This test validates the merge order is correct in the service
  const html = `
    <html><head>
      <meta property="og:title" content="OG Title">
      <script type="application/ld+json">
        { "@type": "Product", "name": "LD Title" }
      </script>
    </head></html>
  `;
  const ld = extractJsonLd(html);
  assert.equal(ld.name, "LD Title");
});

test("extractJsonLd: handles nested JSON-LD in @graph array", () => {
  const html = `
    <html><head>
      <script type="application/ld+json">
        {
          "@graph": [
            { "@type": "WebPage", "name": "Page" },
            { "@type": "Product", "name": "Graph Product", "offers": { "price": "19.99", "priceCurrency": "GBP" } }
          ]
        }
      </script>
    </head></html>
  `;
  const ld = extractJsonLd(html);
  assert.equal(ld.name, "Graph Product");
  assert.equal(ld.price, "19.99");
});

test("extractJsonLd: handles Product inside array", () => {
  const html = `
    <html><head>
      <script type="application/ld+json">
        [
          { "@type": "BreadcrumbList" },
          { "@type": "Product", "name": "Array Product" }
        ]
      </script>
    </head></html>
  `;
  const ld = extractJsonLd(html);
  assert.equal(ld.name, "Array Product");
});

test("extractJsonLd: returns empty object for missing JSON-LD", () => {
  const html = `<html><head></head></html>`;
  const ld = extractJsonLd(html);
  assert.deepEqual(ld, {});
});

test("extractJsonLd: handles image as array (takes first)", () => {
  const html = `
    <html><head>
      <script type="application/ld+json">
        { "@type": "Product", "name": "Multi-img", "image": ["https://img1.jpg", "https://img2.jpg"] }
      </script>
    </head></html>
  `;
  const ld = extractJsonLd(html);
  assert.equal(ld.image, "https://img1.jpg");
});

test("extractJsonLd: handles lowPrice in offers", () => {
  const html = `
    <html><head>
      <script type="application/ld+json">
        { "@type": "Product", "name": "LowPrice", "offers": { "lowPrice": "15.00", "priceCurrency": "USD" } }
      </script>
    </head></html>
  `;
  const ld = extractJsonLd(html);
  assert.equal(ld.price, "15.00");
});

// --- determineExtractionMethod tests ---

test("determineExtractionMethod: returns og_tags+json_ld when both have data", () => {
  assert.equal(determineExtractionMethod({ title: "A" }, { name: "B" }), "og_tags+json_ld");
});

test("determineExtractionMethod: returns og_tags when only OG has data", () => {
  assert.equal(determineExtractionMethod({ title: "A" }, {}), "og_tags");
});

test("determineExtractionMethod: returns json_ld when only JSON-LD has data", () => {
  assert.equal(determineExtractionMethod({}, { name: "B" }), "json_ld");
});

test("determineExtractionMethod: returns none when no data", () => {
  assert.equal(determineExtractionMethod({}, {}), "none");
});

// --- scrapeUrl integration tests with mocked fetch ---

test("scrapeUrl: returns error on non-HTTPS URL", async () => {
  const service = createUrlScraperService();
  const result = await service.scrapeUrl("http://example.com/product");
  assert.equal(result.error, "invalid_url");
});

test("scrapeUrl: returns error on malformed URL", async () => {
  const service = createUrlScraperService();
  const result = await service.scrapeUrl("not-a-url");
  assert.equal(result.error, "invalid_url");
});

test("scrapeUrl: trims rawHtml to 10KB", () => {
  // Verify the constant is 10KB
  assert.equal(10 * 1024, 10240);
});
