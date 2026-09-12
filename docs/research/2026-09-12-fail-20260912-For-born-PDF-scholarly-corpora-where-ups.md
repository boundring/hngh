# For born-PDF scholarly corpora where upstream structure capture is impossible, what post-hoc extraction pipeline (GROBID/TEI-class) meets R1's anchor-and-hierarchy pass/fail criterion?

Status: crystallized 2026-09-12 from research line `fail-20260912-For-born-PDF-scholarly-corpora-where-ups`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-For-born-PDF-scholarly-corpora-where-ups.md.

### Research Line: Post-Hoc Extraction Pipeline for Born-PDF Scholarly Corpora

#### Current Lifecycle State: Contracting

**Objective:**
For born-PDF scholarly corpora where upstream structure capture is impossible, identify a post-hoc extraction pipeline (GROBID/TEI-class) that meets R1's anchor-and-hierarchy pass/fail criterion.

**Final Summary:**

1. **Use GROBID for Initial Extraction:**
   - **Repository Path:** `/home/bricker/Projects/etc/hngh/grobid-extraction`
   - **Description:** GROBID is a powerful tool for extracting structured information from PDF documents. It can be used to extract key elements such as titles, authors, abstracts, sections, and references.
   - **Rationale:** GROBID is designed to handle a wide variety of PDF documents and can be fine-tuned for specific corpora.

2. **Post-Processing with TEI XML:**
   - **Repository Path:** `/home/bricker/Projects/etc/hngh/tei-postprocessing`
   - **Description:** After initial extraction with GROBID, the output can be further processed into TEI XML format. This step ensures that the extracted data is structured and can be easily integrated into a TEI-compliant corpus.
   - **Rationale:** TEI XML is a widely accepted standard for scholarly documents, providing a robust structure for anchoring and hierarchy.

3. **Evaluate Against R1 Criteria:**
   - **Repository Path:** `/home/bricker/Projects/etc/hngh/r1-criteria`
   - **Description:** The R1 criteria include specific pass/fail conditions for anchor and hierarchy. These criteria must be met to ensure the quality and usability of the extracted data.
   - **Rationale:** Ensuring that the extracted data meets the R1 criteria is crucial for the downstream processing and analysis.

4. **Automate the Pipeline:**
   - **Repository Path:** `/home/bricker/Projects/etc/hngh/automation-pipeline`
   - **Description:** Automate the entire extraction and post-processing pipeline to handle large volumes of documents efficiently.
   - **Rationale:** Automation ensures consistency and scalability, making it easier to process a large number of documents.

### Recommendations

- **GROBID for Initial Extraction:**
  - **Repository Path:** `/home/bricker/Projects/etc/hngh/grobid-extraction`
  - **Description:** GROBID is a robust tool for extracting structured information from PDF documents. It can be fine-tuned for specific corpora, ensuring accurate extraction of key elements such as titles, authors, abstracts, sections, and references.

- **TEI XML Postprocessing:**
  - **Repository Path:** `/home/bricker/Projects/etc/hngh/tei-postprocessing`
  - **Description:** Post-processing the GROBID output into TEI XML format ensures that the extracted data is structured and TEI-compliant. This step is crucial for anchoring and hierarchy.

- **R1 Criteria Evaluation:**
  - **Repository Path:** `/home/bricker/Projects/etc/hngh/r1-criteria`
  - **Description:** The R1 criteria define specific pass/fail conditions for anchor and hierarchy. Ensuring the extracted data meets these criteria is essential for the quality and usability of the corpus.

- **Automation of the Pipeline:**
  - **Repository Path:** `/home/bricker/Projects/etc/hngh/automation-pipeline`
  - **Description:** Automating the entire extraction and post-processing pipeline ensures consistency and scalability, making it easier to process large volumes of documents.

### References

1. **GROBID Repository:**
   - Path: `/home/bricker/Projects/etc/hngh/grobid-extraction`

2. **TEI Postprocessing Repository:**
   - Path: `/home/bricker/Projects/etc/hngh/tei-postprocessing`

3. **R1 Criteria Repository:**
   - Path: `/home/bricker/Projects/etc/hngh/r1-criteria`

4. **Automation Pipeline Repository:**
   - Path: `/home/bricker/Projects/etc/hngh/automation-pipeline`

### Unverified Claims

- **Claim:** GROBID can

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
