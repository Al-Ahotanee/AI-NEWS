-- Adds a dedicated Africa category plus verified Nigerian and pan-African
-- RSS sources. Safe to re-run: categories/sources use ON CONFLICT DO NOTHING.

INSERT INTO categories(name,slug,description)
VALUES ('Africa','africa','Nigerian and pan-African news')
ON CONFLICT(slug) DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'Premium Times Nigeria','https://www.premiumtimesng.com','https://www.premiumtimesng.com/feed',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'Vanguard News','https://www.vanguardngr.com','https://www.vanguardngr.com/feed/',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'The Punch','https://punchng.com','https://punchng.com/feed/',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'Daily Post Nigeria','https://dailypost.ng','https://dailypost.ng/feed',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'The Guardian Nigeria','https://guardian.ng','https://guardian.ng/feed/',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'AllAfrica - Nigeria','https://allafrica.com/nigeria/','https://allafrica.com/tools/headlines/rdf/nigeria/headlines.rdf',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;

INSERT INTO sources(name,website_url,rss_url,category_id)
SELECT 'AllAfrica - Continental','https://allafrica.com/latest/','https://allafrica.com/tools/headlines/rdf/latest/headlines.rdf',id
FROM categories WHERE slug='africa' ON CONFLICT DO NOTHING;
