class Endpoint {
  static String baseUrl = "https://demo.primware.net";
  static String request = "$baseUrl/api/v1/models/R_Request";

  static String order = "$baseUrl/api/v1/models/C_Order";
  // Auth Endpoints
  static String authTokens = "$baseUrl/api/v1/auth/tokens";
  static String authRoles = "$baseUrl/api/v1/auth/roles";
  static String authOrgs = "$baseUrl/api/v1/auth/organizations";
  static String authWarehouses = "$baseUrl/api/v1/auth/warehouses";
  static String authLogout = "$baseUrl/api/v1/auth/logout";
}
