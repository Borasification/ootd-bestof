# name: ootd-bestof
# about: A super simple plugin to demonstrate how plugins work
# version: 0.0.1
# authors: Maël Lavault, François Helg
enabled_site_setting :ootd_bestof_enabled

gem 'mime-types-data', '3.2020.0512'
gem 'mime-types', '3.3.1'
gem 'json', '2.3.1'
gem 'multi_xml', '0.6.0'
gem 'httparty', '0.18.1'

add_admin_route 'ootd_bestof.admin.title', 'ootd-bestof'

Discourse::Application.routes.append do
  get '/admin/plugins/ootd-bestof' => 'admin/plugins#index', constraints: StaffConstraint.new
  get '/admin/plugins/ootd-bestof/callback' => 'admin/plugins#index', constraints: StaffConstraint.new
  post '/admin/plugins/ootd-bestof/auth' => 'auth#save', constraints: StaffConstraint.new
end

after_initialize do
  PLUGIN_NAME = "OOTD Bestof"
  OOTD_TOPIC_ID = SiteSetting.ootd_bestof_topic_id

  class ::AuthController < ::ApplicationController
    def save
      access_token = params.require(:access_token)
      refresh_token = params.require(:refresh_token)
      OotdBestof::Store.set("access_token", access_token)
      OotdBestof::Store.set("refresh_token", refresh_token)
      head :ok
    end
  end

  class ::Jobs::OotdBestof < Jobs::Scheduled
    every 1.hour

    def initialize
      @today = Date.today
      @current_time = Time.now
      return unless (@today.saturday? && @current_time.hour == SiteSetting.ootd_bestof_run_hour)
      @ootd_plugin = OotdBestof::OotdBestofController.new
      @imgur_uploader = OotdBestof::ImgurController.new(OotdBestof::Store.get('access_token'))
    end

    def execute(args)
      return unless (@today.saturday? && @current_time.hour == SiteSetting.ootd_bestof_run_hour)
      posts = @ootd_plugin.download_all_posts(Date.today.prev_week())
      album = @imgur_uploader.create_album
      for post in posts do
        for imageUrl in post['images'] do
            @imgur_uploader.upload_images_to_album(album["id"], imageUrl)
        end
      end
    end
  end

  module ::OotdBestof
    class OotdBestof::OotdBestofController < ApplicationController
      include HTTParty
      base_uri 'localhost:3000'
      headers "Api-Username" => SiteSetting.ootd_bestof_discourse_api_username
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
        return response
      end

      def load_posts(grouped_post_ids)
        all_posts = []
        for post_ids in grouped_post_ids do
            options = { query: {'post_ids': post_ids }}
            response = self.class.get("/t/#{OOTD_TOPIC_ID}/posts.json", options)
            all_posts.concat(response['post_stream']['posts'])
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
        return sorted_posts
      end
    end

    class OotdBestof::ImgurController < ApplicationController
      include HTTParty
      debug_output $stdout
      base_uri 'https://api.imgur.com'

      #handle check token in before_action

      def initialize(access_token)
        set_authorization_header(access_token)
      end

      def set_authorization_header(access_token)
        self.class.headers "Authorization" => "Bearer #{access_token}"
      end

      def create_album
        options = {body: {title: "Semaine du #{Date.today.prev_week().strftime("%-d %B")} au #{Date.today.to_s(:long)}"}}
        response = self.class.post('/3/album', options)
        if response.code == 200
          return response
        elsif access_token_has_expired?(response)
          refresh_access_token
          create_album
        else
          puts "Error creating album"
        end
      end

      def upload_images_to_album(albumId, imageUrl)
        options = {body: {image: imageUrl, album: albumId, type: "url"}} #title: imageTitle, description: imageDescription
        response = self.class.post('/3/upload', options)
        if response.code == 200
          return response
        elsif access_token_has_expired?(response)
          refresh_access_token
          upload_images_to_album(albumId, imageUrl)
        else
          puts "Error creating album"
        end
      end

      def access_token_has_expired?(response)
        response.code == 403 && response['data']['error'] =~ /access token.*?expired/i
      end

      def exchange_refresh_token_for_access_token
        options = {body: {refresh_token: OotdBestof::Store.get("refresh_token"), client_id: SiteSetting.ootd_bestof_imgur_client_id, client_secret:SiteSetting.ootd_bestof_imgur_client_secret , grant_type: "refresh_token"}}
        response = self.class.post('/oauth2/token', options)
        if response.code == 200
          OotdBestof::Store.set("access_token", response["access_token"])
          OotdBestof::Store.set("refresh_token", response["refresh_token"])
          return response["access_token"]
        end
        return nil
      end

      def refresh_access_token
        if OotdBestof::Store.get("refresh_token")
          access_token = exchange_refresh_token_for_access_token
          if access_token
            set_authorization_header(access_token)
          end
        else
          #redirect for auth
        end
      end
    end

    require_dependency 'plugin_store'

    class Store
      def self.set(key, value)
        ::PluginStore.set(PLUGIN_NAME, key, value)
      end

      def self.get(key)
        ::PluginStore.get(PLUGIN_NAME, key)
      end

      def self.remove(key)
        ::PluginStore.remove(PLUGIN_NAME, key)
      end
    end
  end
end


