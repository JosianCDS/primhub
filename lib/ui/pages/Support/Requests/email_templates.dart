// ARCHIVO COMENTADO TEMPORALMENTE MIENTRAS SE MIGRAN LAS PLANTILLAS A IDEMPIERE
/*
class EmailTemplates {
  static String buildRequestUpdateEmail({
    required String emailTitle,
    required String userName,
    required String documentNo,
    required String statusName,
    String? updateText,
    String? oldStatusName,
  }) {
    String updateHtmlBlock = '';
    if (updateText != null && updateText.isNotEmpty && updateText != '<p><br></p>') {
      updateHtmlBlock = '''
      <div style="margin: 24px 0; padding: 20px; background-color: #F8F9FA; border-left: 4px solid #494371; border-radius: 0 8px 8px 0;">
        <p style="margin: 0 0 8px 0; font-size: 12px; color: #48464E; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600;">Detalle de la Actualización</p>
        <div style="color: #1C1B1E; font-size: 15px; line-height: 1.6; margin: 0;">
          $updateText
        </div>
      </div>
      ''';
    }

    String statusHtmlBlock = '';
    if (oldStatusName != null && oldStatusName != statusName && oldStatusName.isNotEmpty) {
      // Uso de una tabla HTML para asegurar un alineado vertical perfecto en todos los clientes de correo (Gmail, Outlook, etc)
      statusHtmlBlock = '''
      <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="margin: 24px auto;">
        <tr>
          <td align="center" valign="middle">
            <span style="display: inline-block; background-color: #E5E1E6; color: #48464E; padding: 8px 16px; border-radius: 9999px; font-size: 14px; font-weight: 600; border: 1px solid #C9C5CF;">
              $oldStatusName
            </span>
          </td>
          <td align="center" valign="middle" style="padding: 0 12px;">
            <span style="color: #494371; font-size: 18px; font-weight: bold;">➔</span>
          </td>
          <td align="center" valign="middle">
            <span style="display: inline-block; background-color: #E6F8F5; color: #00B69B; padding: 8px 16px; border-radius: 9999px; font-size: 14px; font-weight: 600; border: 1px solid #00B69B;">
              $statusName
            </span>
          </td>
        </tr>
      </table>
      ''';
    } else {
      statusHtmlBlock = '''
      <div style="margin: 24px 0; text-align: center;">
        <span style="display: inline-block; background-color: #EAE8F4; color: #494371; padding: 8px 16px; border-radius: 9999px; font-size: 14px; font-weight: 600; border: 1px solid #494371;">
          $statusName
        </span>
      </div>
      ''';
    }

    return \'\'\'
<div style="font-family: 'Poppins', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F3F4F6; padding: 40px 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #FFFFFF; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);">
    <div style="background-color: #494371; padding: 24px; text-align: center;">
      <h2 style="margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 600;">$emailTitle</h2>
    </div>
    <div style="padding: 32px;">
      <p style="font-size: 16px; color: #1C1B1E; line-height: 1.6; margin-top: 0;">Hola <strong style="color: #494371;">$userName</strong>,</p>
      <p style="font-size: 16px; color: #1C1B1E; line-height: 1.6;">La solicitud ha sido procesada:</p>
      
      $statusHtmlBlock

      $updateHtmlBlock
      
      <hr style="border: 0; border-top: 1px solid #E5E1E6; margin: 32px 0;">
      <p style="font-size: 14px; color: #78767F; line-height: 1.6; margin: 0;">Atentamente,<br><strong style="color: #48464E;">El equipo técnico</strong></p>
      <p style="font-size: 12px; color: #928F99; line-height: 1.5; margin-top: 16px; font-style: italic;">(Favor no responder a este correo, ya que no es monitoreado)</p>
    </div>
  </div>
</div>
\'\'\';
  }
}
*/
