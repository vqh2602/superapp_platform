export class UIMockHandler {
  public async showToast(payload: { message: string; duration?: number }): Promise<any> {
    if (typeof window !== 'undefined') {
      console.log(`[Toast] ${payload.message}`);
    }
    return { success: true, message: payload.message };
  }

  public async showAlert(payload: { title: string; message: string; buttonText?: string }): Promise<any> {
    if (typeof window !== 'undefined' && typeof window.alert === 'function') {
      window.alert(`${payload.title}\n\n${payload.message}`);
    }
    return { confirmed: true };
  }

  public async showConfirm(payload: { title: string; message: string; confirmText?: string; cancelText?: string }): Promise<any> {
    let confirmed = true;
    if (typeof window !== 'undefined' && typeof window.confirm === 'function') {
      confirmed = window.confirm(`${payload.title}\n\n${payload.message}`);
    }
    return { confirmed };
  }

  public async setNavigationBarTitle(payload: { title: string }): Promise<any> {
    if (typeof document !== 'undefined') {
      document.title = payload.title;
    }
    return { success: true, title: payload.title };
  }

  public async setStatusBarColor(payload: { color: string }): Promise<any> {
    return { success: true, color: payload.color };
  }

  public async setNavigationBarColor(payload: { color: string; textColor?: string; statusBarColor?: string }): Promise<any> {
    return {
      success: true,
      color: payload.color,
      textColor: payload.textColor || 'black',
      statusBarColor: payload.statusBarColor,
    };
  }

  public async configAppView(payload: any = {}): Promise<any> {
    return {
      success: true,
      actionBarHidden: !!payload.actionBarHidden,
      statusBar: payload.statusBar || 'transparent',
      hideAndroidBottomNavigationBar: !!payload.hideAndroidBottomNavigationBar,
      hasPadding: payload.hasPadding !== false,
      ...payload,
    };
  }

  public async requestSendNotification(payload: { templateId?: string; reason?: string } = {}): Promise<any> {
    return {
      success: true,
      granted: true,
      subscriptionId: `mock_sub_${Date.now()}`,
      token: `mock_notif_token_${Date.now()}`,
      templateId: payload.templateId,
      reason: payload.reason,
    };
  }
}
