using UnityEngine;

[RequireComponent(typeof(Camera))]
public class FreeCameraController : MonoBehaviour
{
    [Header("Movement Settings")]
    [SerializeField] private float moveSpeed = 7.0f;      // 基础移动速度
    [SerializeField] private float sprintMultiplier = 2.5f; // 加速倍率

    [Header("Look Settings")]
    [SerializeField] private float mouseSensitivity = 100f; // 鼠标灵敏度
    [SerializeField][Range(0, 90)] private float maxVerticalAngle = 80f; // 最大俯仰角

    private float _rotationX = 0f;   // 当前X轴旋转角度
    private float _rotationY = 0f;   // 当前Y轴旋转角度
    private bool _isMouseLocked = false;

    void Start()
    {
        // 初始化旋转角度为当前相机的欧拉角
        Vector3 rot = transform.eulerAngles;
        _rotationY = rot.y;
        _rotationX = rot.x;
    }

    void Update()
    {
        HandleMovement();
        HandleRotation();
    }

    // 处理键盘移动
    private void HandleMovement()
    {
        // 获取输入方向（WASD）
        float horizontal = 0f;
        float vertical = 0f;
        float rise = 0f;

        if (Input.GetKey(KeyCode.W)) vertical = 1;
        if (Input.GetKey(KeyCode.S)) vertical = -1;
        if (Input.GetKey(KeyCode.A)) horizontal = -1;
        if (Input.GetKey(KeyCode.D)) horizontal = 1;

        // 升降控制（Q/E）
        if (Input.GetKey(KeyCode.Q)) rise = -1;
        if (Input.GetKey(KeyCode.E)) rise = 1;

        // 计算移动方向
        Vector3 direction = new Vector3(horizontal, rise, vertical).normalized;

        // 计算实际速度（是否按下Shift加速）
        float speed = moveSpeed * (Input.GetKey(KeyCode.LeftShift) ? sprintMultiplier : 1f);
        speed *= Time.deltaTime;

        // 执行移动（基于本地坐标系）
        transform.Translate(direction * speed);
    }

    // 处理鼠标视角
    private void HandleRotation()
    {
        // 按下鼠标右键时激活视角控制
        if (Input.GetMouseButtonDown(1))
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
            _isMouseLocked = true;
        }
        if (Input.GetMouseButtonUp(1))
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
            _isMouseLocked = false;
        }

        if (!_isMouseLocked) return;

        // 获取鼠标增量
        float mouseX = Input.GetAxis("Mouse X") * mouseSensitivity * Time.deltaTime;
        float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivity * Time.deltaTime;

        // 计算旋转角度（限制垂直角度）
        _rotationY += mouseX;
        _rotationX -= mouseY;
        _rotationX = Mathf.Clamp(_rotationX, -maxVerticalAngle, maxVerticalAngle);

        // 应用旋转
        transform.rotation = Quaternion.Euler(_rotationX, _rotationY, 0);
    }
}