import { ajax } from "discourse/lib/ajax";

export default Ember.Controller.extend({
  actions: {
    saveAuth(hashParams) {
      if (!hashParams) {
        return;
      }

      return ajax("/admin/plugins/ootd-bestof/auth", {
        type: "POST",
        data: {
          access_token: hashParams.access_token,
          refresh_token: hashParams.refresh_token,
        },
      })
        .then((response) => {
          console.log(response);
        })
        .catch(console.log);
    },
  },
});
