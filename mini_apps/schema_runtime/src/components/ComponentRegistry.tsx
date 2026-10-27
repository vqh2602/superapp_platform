import React from 'react';
import { ComponentDefinition } from '../types';
import {
  ShoppingBag,
  ArrowRight,
  CheckCircle2,
  QrCode,
  LogOut,
  Play,
  MessageSquare,
  Sparkles,
  Gamepad2,
  Phone,
  User,
  Video,
  ShieldCheck,
  Heart,
  Send,
} from 'lucide-react';

interface ComponentProps {
  definition: ComponentDefinition;
  onAction: (action: any) => void;
  renderChild: (child: ComponentDefinition) => React.ReactNode;
}

export const TextComponent: React.FC<ComponentProps> = ({ definition }) => {
  const { value, variant = 'body', align = 'left', color } = definition.props;
  const style: React.CSSProperties = {
    textAlign: align,
    color: color || undefined,
  };

  switch (variant) {
    case 'h1':
      return <h1 style={{ ...style, fontSize: '24px', fontWeight: 800, margin: '8px 0' }}>{value}</h1>;
    case 'h2':
      return <h2 style={{ ...style, fontSize: '20px', fontWeight: 700, margin: '6px 0' }}>{value}</h2>;
    case 'h3':
      return <h3 style={{ ...style, fontSize: '16px', fontWeight: 700, margin: '4px 0' }}>{value}</h3>;
    case 'subtitle':
      return <p style={{ ...style, fontSize: '13px', color: color || '#64748B', margin: '2px 0' }}>{value}</p>;
    default:
      return <p style={{ ...style, fontSize: '14px', lineHeight: 1.5, margin: '4px 0' }}>{value}</p>;
  }
};

export const ImageComponent: React.FC<ComponentProps> = ({ definition }) => {
  const { src, alt = '', height = 180, borderRadius = 12 } = definition.props;
  return (
    <img
      src={src || 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=600&q=80'}
      alt={alt}
      style={{
        width: '100%',
        height: typeof height === 'number' ? `${height}px` : height,
        objectFit: 'cover',
        borderRadius: `${borderRadius}px`,
        display: 'block',
        margin: '6px 0',
      }}
    />
  );
};

export const ButtonComponent: React.FC<ComponentProps> = ({ definition, onAction }) => {
  const { label, text, variant = 'primary', icon, fullWidth = true, backgroundColor, color: customColor } = definition.props;
  const displayLabel = label || text || 'Button';

  let bg = '#2563EB';
  let color = '#FFFFFF';
  let border = 'none';

  if (variant === 'secondary') {
    bg = '#F1F5F9';
    color = '#1E293B';
  } else if (variant === 'outline') {
    bg = 'transparent';
    color = '#2563EB';
    border = '1px solid #2563EB';
  } else if (variant === 'danger') {
    bg = '#EF4444';
    color = '#FFFFFF';
  } else if (variant === 'success') {
    bg = '#10B981';
    color = '#FFFFFF';
  }

  if (backgroundColor) bg = backgroundColor;
  if (customColor) color = customColor;

  const renderIcon = () => {
    if (icon === 'cart') return <ShoppingBag size={16} />;
    if (icon === 'arrow') return <ArrowRight size={16} />;
    if (icon === 'qr') return <QrCode size={16} />;
    if (icon === 'close') return <LogOut size={16} />;
    if (icon === 'play') return <Play size={16} />;
    if (icon === 'message') return <MessageSquare size={16} />;
    if (icon === 'sparkles') return <Sparkles size={16} />;
    if (icon === 'gamepad') return <Gamepad2 size={16} />;
    if (icon === 'phone') return <Phone size={16} />;
    if (icon === 'user') return <User size={16} />;
    if (icon === 'video') return <Video size={16} />;
    if (icon === 'shield') return <ShieldCheck size={16} />;
    if (icon === 'heart') return <Heart size={16} />;
    if (icon === 'send') return <Send size={16} />;
    return null;
  };

  return (
    <button
      onClick={() => definition.events?.onClick && onAction(definition.events.onClick)}
      style={{
        width: fullWidth ? '100%' : 'auto',
        backgroundColor: bg,
        color,
        border,
        padding: '12px 18px',
        borderRadius: '10px',
        fontSize: '14px',
        fontWeight: 700,
        cursor: 'pointer',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '8px',
        margin: '6px 0',
        transition: 'transform 0.1s, opacity 0.1s',
      }}
    >
      {renderIcon()}
      <span>{displayLabel}</span>
    </button>
  );
};

export const ContainerComponent: React.FC<ComponentProps> = ({ definition, renderChild }) => {
  const {
    padding = 16,
    backgroundColor = '#FFFFFF',
    borderRadius = 14,
    border = true,
    shadow = true,
    flexDirection = 'column',
  } = definition.props;

  return (
    <div
      style={{
        backgroundColor,
        padding: `${padding}px`,
        borderRadius: `${borderRadius}px`,
        border: border ? '1px solid #E2E8F0' : 'none',
        boxShadow: shadow ? '0 2px 8px rgba(0,0,0,0.04)' : 'none',
        display: 'flex',
        flexDirection: flexDirection as any,
        gap: '8px',
        margin: '8px 0',
      }}
    >
      {definition.children?.map((child) => renderChild(child))}
    </div>
  );
};

export const ProductCardComponent: React.FC<ComponentProps> = ({ definition, onAction }) => {
  const {
    title = 'Sản phẩm mẫu',
    price = 45000,
    currency = '₫',
    description = 'Mô tả sản phẩm',
    image,
    buttonText = 'Đặt mua ngay',
  } = definition.props;

  const handleBuy = () => {
    if (definition.events?.onClick) {
      onAction(definition.events.onClick);
    } else {
      // Default payment checkout action
      onAction({
        type: 'native_action',
        action: 'payment.openCheckout',
        params: {
          amount: price,
          description: `Thanh toán: ${title}`,
          currency: 'VND',
        },
      });
    }
  };

  return (
    <div
      style={{
        backgroundColor: '#FFFFFF',
        border: '1px solid #E2E8F0',
        borderRadius: '14px',
        padding: '12px',
        display: 'flex',
        gap: '12px',
        alignItems: 'center',
        margin: '8px 0',
        boxShadow: '0 2px 6px rgba(0,0,0,0.03)',
      }}
    >
      {image && (
        <img
          src={image}
          alt={title}
          style={{ width: '70px', height: '70px', borderRadius: '10px', objectFit: 'cover' }}
        />
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <h4 style={{ fontSize: '14px', fontWeight: 700, margin: 0, color: '#0F172A' }}>{title}</h4>
        <p style={{ fontSize: '12px', color: '#64748B', margin: '2px 0 6px 0' }}>{description}</p>
        <span style={{ fontSize: '14px', fontWeight: 800, color: '#2563EB' }}>
          {Number(price).toLocaleString('vi-VN')} {currency}
        </span>
      </div>
      <button
        onClick={handleBuy}
        style={{
          backgroundColor: '#2563EB',
          color: 'white',
          border: 'none',
          padding: '8px 12px',
          borderRadius: '8px',
          fontSize: '12px',
          fontWeight: 700,
          cursor: 'pointer',
          whiteSpace: 'nowrap',
        }}
      >
        {buttonText}
      </button>
    </div>
  );
};

export const ProductListComponent: React.FC<ComponentProps> = ({ definition, onAction }) => {
  const items = definition.props.items || [
    { id: '1', title: 'Cà phê Phin Sữa Đá', price: 39000, desc: 'Đậm đà truyền thống' },
    { id: '2', title: 'Trà Đào Cam Sả', price: 49000, desc: 'Thơm ngọt thanh mát' },
    { id: '3', title: 'Bánh Croissant Bơ Tỏi', price: 35000, desc: 'Nóng giòn thơm bơ' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', margin: '8px 0' }}>
      {items.map((item: any) => (
        <ProductCardComponent
          key={item.id}
          definition={{
            id: `prod_${item.id}`,
            type: 'product_card',
            props: {
              title: item.title,
              price: item.price,
              description: item.desc,
              image: item.image,
            },
          }}
          onAction={onAction}
          renderChild={() => null}
        />
      ))}
    </div>
  );
};

export const InputComponent: React.FC<ComponentProps> = ({ definition }) => {
  const { label, placeholder = 'Nhập thông tin...', type = 'text' } = definition.props;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', margin: '6px 0' }}>
      {label && <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569' }}>{label}</label>}
      <input
        type={type}
        placeholder={placeholder}
        style={{
          padding: '10px 14px',
          border: '1px solid #CBD5E1',
          borderRadius: '8px',
          fontSize: '14px',
          outline: 'none',
          backgroundColor: '#F8FAFC',
        }}
      />
    </div>
  );
};

export const renderComponent = (
  component: ComponentDefinition,
  onAction: (action: any) => void,
): React.ReactNode => {
  const props: ComponentProps = {
    definition: component,
    onAction,
    renderChild: (child) => renderComponent(child, onAction),
  };

  switch (component.type) {
    case 'text':
      return <TextComponent key={component.id} {...props} />;
    case 'image':
      return <ImageComponent key={component.id} {...props} />;
    case 'button':
      return <ButtonComponent key={component.id} {...props} />;
    case 'container':
      return <ContainerComponent key={component.id} {...props} />;
    case 'product_card':
      return <ProductCardComponent key={component.id} {...props} />;
    case 'product_list':
      return <ProductListComponent key={component.id} {...props} />;
    case 'input':
      return <InputComponent key={component.id} {...props} />;
    default:
      return (
        <div key={component.id} style={{ color: 'red', fontSize: '11px' }}>
          Unknown component type: {component.type}
        </div>
      );
  }
};
