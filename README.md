## GlobalVoices - A Sample GenderTracker Client

[GlobalVoices](http://globalvoicesonline.org/) is an international community of bloggers who report on blogs and citizen media from around the world. As a first attempt to test the GenderTracker system, we are working with GlobalVoices data to evaluate its content's gender diversity.

Note: in 2018, several years after publishing the original Guardian article, we removed the data from this analysis upon request from some participants in the project. If researchers are interested in re-analyzing this project to double-check our results, please contact J. Nathan Matias. With approval from a university ethics board, this may be possible if it falls within the original purpose of the data collection.

## Requirements

1. get jruby 1.6.3 by your favorite method of choice. I recommend rvm.
2. run `gem install bundler`
3. run `bundle install`
4. Intall redis
5. Run redis.
6. Make sure the genderTracker server is running.

## Folders and their meaning

There are several key folders of interest:

1. The `data` folder contains the available data for global voices. Note there are two collections in place:

* `sample` - a small sample of the articles (about 1800)
* `full` - 9 years worth of content

This folder contains the raw data. In this case, an xml feed.

2. Once articles get processed, they go into the `articles` folder under the apporpriate collection name. Note we don't check those files in since the full collection especially is rather large. You can generate them yourself.

## Available Scripts

### `prepare.rb`

This script converts the xml data into the article.json files. It doens't talk to the GenderTracker service yet. To execute it, run:

`bundle exec prepare.rb sample` (or other collection name)

### `process.rb`

This script actually sends the availble article json files inside a specific collection to be processed by the main genderTracker service (so make sure you have that running.)

The script terminates when all articles have been processed.

Note it requires `redis` to run, so make sure both the genderTracker service and the process.rb script are pointing to the same redis queue. You can change that in the `config.yaml`.

Note that the genderTracker service actually modifies the filepaths that it recieves, so it must have read and write access to them.

To execute the script, run:

`bundle exec process.rb sample` (or other collection name)

### `aggregate.rb`

This script is responsible for assembling some csvs about the processed files. By deault it creates all its files in the `assets` folder. Two files are generated: 

* `*_all.csv` - a csv of all the articles, their pub date and the results of the metrics.
* `*_names.csv` - A unique list of authors that contributed to the above set of articles and our guess as to their gender.

To execute the script, run:

`bundle exec ruby aggregate.rb sample` (or other collection name)

`bundle exec ruby aggregate.rb sample CategoryName` (any category that appears in the category property of articles.)

## Licensing

The project is duel licensed under the GPLv3 license as well as the MIT license. Pick your favorite.

