export default Ember.Controller.extend({
  actions: {
    showAuthorizationWindow() {
      window.open(
        `https://api.imgur.com/oauth2/authorize?client_id=${this.siteSettings.ootd_bestof_imgur_client_id}&response_type=token`
      );
    },
  },
});
