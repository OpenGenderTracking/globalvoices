import json
import re

special_page_hash = json.loads(open("articles/pages/427448.json").read())

gv_slugs = [re.sub(".*\/","",x[0:-1]) for x in special_page_hash["link_hrefs"] if ( (x.find("globalvoicesonline.org")is not -1) and (x.find("author") is -1) ) ]

for slug in gv_slugs:
  print slug
