export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("ootd-bestof", function () {
      this.route("callback");
    });
  },
};
