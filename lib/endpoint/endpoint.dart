class Envirioment {
  static bool isProduction = false;
}

class Endpoint {
  static String baseUrl = Envirioment.isProduction ? "https://erp.primware.net" : "https://primhub.primware.net";
  static String request = "$baseUrl/api/v1/models/R_Request";
  static String order = "$baseUrl/api/v1/models/C_Order";
  static String productChip = "$baseUrl/api/v1/models/C_BPartner_Product_Chip";
  static String cBPartner = "$baseUrl/api/v1/models/C_BPartner";
  static String adUser = "$baseUrl/api/v1/models/AD_User";
  static String primConfig = "$baseUrl/api/v1/models/Prim_Config";
  static String project = "$baseUrl/api/v1/models/C_Project";
  static String primDocuments = "$baseUrl/api/v1/models/PRIM_Documents";
  static String currency = "$baseUrl/api/v1/models/C_Currency";
  static String authTokens = "$baseUrl/api/v1/auth/tokens";
  static String authRoles = "$baseUrl/api/v1/auth/roles";
  static String authOrgs = "$baseUrl/api/v1/auth/organizations";
  static String authWarehouses = "$baseUrl/api/v1/auth/warehouses";
  static String authLogout = "$baseUrl/api/v1/auth/logout";
  static String primDocumentsRelated = "$baseUrl/api/v1/models/PRIM_Documents_Related";
}

class PostMedia {
  final int recordID;
  final String tableName;

  PostMedia({required this.recordID, required this.tableName});

  String get endPoint {
    if (tableName.startsWith('http')) {
      return '$tableName/$recordID/attachments';
    }
    return '${Endpoint.baseUrl}/api/v1/models/$tableName/$recordID/attachments';
  }
}
