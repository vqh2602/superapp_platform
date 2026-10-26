export interface ComponentAction {
  type: 'navigate' | 'native_action' | 'url';
  action?: string; // e.g. 'payment.openCheckout', 'device.scanQRCode', 'navigation.close', 'user.getBasicInfo'
  params?: Record<string, any>;
  targetPageId?: string; // for type: 'navigate'
}

export interface ComponentDefinition {
  id: string;
  type:
    | 'text'
    | 'image'
    | 'button'
    | 'container'
    | 'product_card'
    | 'product_list'
    | 'input'
    | 'form';
  props: Record<string, any>;
  events?: {
    onClick?: ComponentAction;
    onSubmit?: ComponentAction;
  };
  children?: ComponentDefinition[];
}

export interface PageDefinition {
  id: string;
  title: string;
  components: ComponentDefinition[];
}

export interface MiniAppSchema {
  schemaVersion: number;
  pages: PageDefinition[];
  theme?: {
    primaryColor?: string;
    backgroundColor?: string;
  };
}
