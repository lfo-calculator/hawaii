# Readme for Section 291 "Catala Regs"

This directory contains a set of Catala files that map subsection by subsection to [Section 291 of the Hawaii Revised Statutes](https://sammade.github.io/aloha-io/). It is intended to provide the translation layer between the regulations themselves and the Catala-based "back end" that powers this version of the LFO Calculator being built for the State of Hawaii.

The interaction dynamic between the regulations and the calculator is via these Catala language input files. It is assumed that if one can parse the regulations in a real-world context, and understand the interplay between and across the regulations for sentencing, fees, and fines, one can readily interpret the logical calculation structure of the corresponding Catala input file as well. (It is imperative that *someone*, ideally *multiple people*, verify the outcome produced by the calculator is consistent with real-world expectations.)

## Grammar and Structure of the Catala Input Files

While the Catala input files are processed by the Catala compiler, they are also human readable. The legal text and the corresponding Catala programming structures are presented side by side, with the intent that legal practictioners that are not developers should be able to reason over the grammar and structure of the programming logic without needing to be conversant in the language itself.

### Naming and Mapping Convention

Each file maps to a corresponding and distinct subsection of the Hawaii Revised Statutes. Only active sections are included.

For the sake of web rendering and other accommodations, dots are replaced with dashes for lower-level subsections (*i.e.*, 291-3.3 in the regulations will map to 291-3-3 in the corresponding Catala language file)

### File Structure

foo

## Interaction with Web-based Front-end



## Notes and Errata for Reviewers

Given the override- and exception-based nature of legal text, and its practice to fix previous problems or provide subsequent clarifications by generating additional unreferenced or otherwise independent pieces of legislation, there are often very important linkages across regulations not specifically addressed or referenced in the original text itself. This section of the readme is intended to call attention to the major cross-sectional considerations or otherwise unreferenced factors nonetheless critical to an accurate LFO assessment.
