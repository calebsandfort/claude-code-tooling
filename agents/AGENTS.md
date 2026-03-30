# SME Agent Registry

This file maps `[SME:*]` annotation tags found in High-Level Requirements Documents to their corresponding agent slugs. The Product Manager agent reads this file to resolve which SME agent to invoke for each tag.

## Tag-to-Agent Mappings

| SME Tag | Agent Slug | Description |
|---------|-----------|-------------|
| BehavioralCoach | behavioral-psychology-sme | Behavioral psychology, trading psychology, habit formation, intervention design, cognitive biases |
| AIWorkflow | ai-nlp-sme | AI/NLP architecture, prompt engineering, agent workflows, LLM inference optimization |
| DataScientist | data-analytics-sme | Data modeling, analytics, visualization, statistical methods, time-series data |
| LegalDomain | legal-domain-sme | Legal practice operations, solo/small firm workflows, court procedures, client communication conventions |
| SocialMediaDomain | social-media-domain-sme | Social media management, brand monitoring, trend response, platform conventions, agency operations |
| EcommerceDomain | ecommerce-domain-sme | E-commerce seller operations, marketplace management, customer service, inventory, review management |
| UXDesigner | ux-designer-sme | UX/UI design, dashboard layouts, approval workflow UX, information architecture, professional tool interfaces |
| IntegrationEngineer | integration-engineer-sme | Multi-tenancy, data source connectors, database architecture, API design, authentication, data pipelines |
| ConsumerSpending | consumer-spending-sme | Consumer spending behavior, market research, product positioning, pricing strategies |
| MarketAnalyst | market-analyst-sme | Market analysis, competitive research, industry trends, SWOT analysis, strategic planning |

## Usage

When processing an HLRD, the orchestrator:

1. Parses all `[SME:TagName]` annotations from the document
2. Looks up the corresponding agent slug in the table above
3. Routes the annotated questions to the matched SME agent

## Adding New SMEs

To add a new SME:

1. Create an agent file at `~/.claude/agents/<agent-slug>.md`
2. Add a row to the mapping table above
3. The new SME will be available for use in `/elaborate-requirements` invocations
