# name: ootd-bestof
# about: A super simple plugin to demonstrate how plugins work
# version: 0.0.1
# authors: Maël Lavault

gem 'mime-types-data', '3.2020.0512'
gem 'mime-types', '3.3.1'
gem 'json', '2.3.1'
gem 'multi_xml', '0.6.0'
gem 'httparty', '0.18.1'


OOTD_TOPIC_ID = 11

after_initialize do
  class ::Jobs::OOTDBestof < Jobs::Scheduled
    every 30.seconds

    def initialize
      @ootd_plugin = OOTDBestof::OOTDBestofController.new
      @imgur_uploader = OOTDBestof::ImgurController.new
    end

    def execute(args)
      posts = @ootd_plugin.download_all_posts(Date.today.weeks_ago(1).beginning_of_week(:sunday))
      albumHash = @imgur_uploader.create_album
      # @imgur_uploader.upload_images_to_album(albumHash)
    end
  end

  require 'httparty'
  module ::OOTDBestof
    class OOTDBestof::OOTDBestofController < ApplicationController
      include HTTParty
      debug_output $stdout
      base_uri 'localhost:3000'
      headers "Api-Username" => 'mael.lavault'
      headers "Api-Key" => SiteSetting.ootd_bestof_discourse_api_key
      headers 'Content-Type' => 'application/json'
      headers 'X-Requested-With' => 'XMLHttpRequest'
      headers 'Accept' => 'application/json'

      def name
        'OOTD Bestof'
      end

      def search_posts(start_date, page=1)
        options = { query: {q: "with:images topic:#{OOTD_TOPIC_ID} after:#{start_date} order:latest", page: page} }
        response = self.class.get('/search', options)
        response.parsed_response
      end

      def load_posts(grouped_post_ids)
        all_posts = []
        for post_ids in grouped_post_ids do
            options = { query: {'post_ids': post_ids }}
            response = self.class.get("/t/#{OOTD_TOPIC_ID}/posts.json", options)
            all_posts.concat(response.parsed_response()['post_stream']['posts'])
        end

        # return the list of posts
        return all_posts
      end

      def download_all_posts(start_date)
        # Init var
        post_ids = []
        more_full_page_results = true
        page = 1

        # Results are paginated, so keep searching while there are more pages available
        while more_full_page_results do

            # Search
            result = search_posts(start_date, page)
            for post in result['posts'] do

                # Create a data structure to keep relevant data
                post_ids.push(post["id"])
            end
            # Check if more pages are availble. Loop if this is the case
            more_full_page_results = result['grouped_search_result']['more_full_page_results']
            page += 1
        end

        # Group ids by 25, because the Discourse API cannot ingest more at a time
        post_id_grouped_by_25 = post_ids.each_slice(25)
        posts = load_posts(post_id_grouped_by_25)
        final_posts = []
        for post in posts do
          # Only consider posts with at least an image
          next unless post.key?("link_counts")

          # Get the id
          id = post['id']

          # Get the username
          username = post['username']

          # Likes seem to be stored in the count element of the first element of the action_summary array...
          # Default to 0 if not found
          likes = post['actions_summary'][0].fetch('count', 0)

          # The post itself
          post_content = post['cooked']

          images = []
          for link_count in post['link_counts'] do
            images.append(link_count['url'])
          end

          final_posts.append(
            {
              "id" => id,
              "username" => username,
              "likes" => likes,
              "created_at" => post['created_at'],
              "images" => images,
              "post_content" => post_content
            }
          )
        end

        # sort the posts by likes
        sorted_posts = final_posts.sort_by! { |k| -k["likes"]}

        puts sorted_posts

        # # Write output in a file on disk
        # Path(f"output/week_{start_date}_{end_date}/images").mkdir(parents=True, exist_ok=True)
        # Path(f"output/week_{start_date}_{end_date}/posts").mkdir(parents=True, exist_ok=True)

        # with open(f"output/week_{start_date}_{end_date}/images/images_url.txt","w+") as posts_file:
        #     for post in sorted_posts
        #         for image_url in post['images'] do
        #             posts_file.write(f'{image_url}\n')
        #         end
        #       end

        # with open(f"output/week_{start_date}_{end_date}/posts/ordered_ootd_posts.txt","w+") as posts_file:
        #     for post in sorted_posts do
        #         posts_file.write(f'{json.dumps(post)}\n')
        #     end
      end
    end

    class OOTDBestof::ImgurController < ApplicationController
      include HTTParty
      debug_output $stdout
      base_uri 'api.imgur.com/3'
      headers "Authorization" => "Bearer #{SiteSetting.ootd_bestof_ingur_api_key}"
      headers 'Content-Type' => 'application/json'
      headers 'Accept' => 'application/json'

      def create_album
        options = {body: {title: 'My dank meme album', description: 'This albums contains a lot of dank memes. Be prepared.', cover: imageHash}
        response = self.class.post('/album', options)
        puts response.parsed_response
      end

      def upload_images_to_album(albumHash)
        options = {body: {image: imageUrl, album: @albumHash, title: imageTitle, description: imageDescription}
        response = self.class.post('/upload', options)
        puts response.parsed_response
      end
    end
  end
end


