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
}
