using System.Runtime.InteropServices;

// 重定义工具类
public static class ReinterpretExtensions
{
    // 使结构体的两个字段共享4字节内存，同样的数据不同的类型解释
    [StructLayout(LayoutKind.Explicit)]
    struct IntFloat
    {
        [FieldOffset(0)]
        public int intValue;

        [FieldOffset(0)]
        public float floatValue;
    }
    public static float ReinterpretAsFloat(this int value)
    {
        IntFloat converter = default;
        converter.intValue = value;
        return converter.floatValue;
    }
}