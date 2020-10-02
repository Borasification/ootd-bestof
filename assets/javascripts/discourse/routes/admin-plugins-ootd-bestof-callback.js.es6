import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  // activate() {

  // },
  actions: {
    didTransition() {
      const hashParams = this.actions.parseParams(document.location.hash);
      this.controller.actions.saveAuth(hashParams);
    },
    parseParams(hash) {
      const cleanedHash = hash.substring(1);
      const pieces = cleanedHash.split("&");
      const data = {};
      let parts = [];
      // process each query pair
      for (let i = 0; i < pieces.length; i++) {
        parts = pieces[i].split("=");
        if (parts.length < 2) {
          parts.push("");
        }
        data[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1]);
      }
      return data;
    },
  },
});
