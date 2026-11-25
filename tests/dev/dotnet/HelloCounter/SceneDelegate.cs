namespace HelloCounter;

/// A label and a button: each tap adds one to the count (the check taps it through x86Sim's MCP tools)
[Register ("SceneDelegate")]
public class SceneDelegate : UIResponder, IUIWindowSceneDelegate {
	int count;

	[Export ("window")]
	public UIWindow? Window { get; set; }

	[Export ("scene:willConnectToSession:options:")]
	public void WillConnect (UIScene scene, UISceneSession session, UISceneConnectionOptions connectionOptions)
	{
		if (scene is not UIWindowScene windowScene)
			return;
		Window ??= new UIWindow (windowScene);

		var label = new UILabel {
			Text = "Count: 0",
			Font = UIFont.BoldSystemFontOfSize (28),
			TextAlignment = UITextAlignment.Center,
		};
		var button = UIButton.FromType (UIButtonType.System);
		button.SetTitle ("Add one", UIControlState.Normal);
		button.TouchUpInside += (_, _) => label.Text = $"Count: {++count}";

		var stack = new UIStackView (new UIView [] {
			new UILabel { Text = ".NET for iOS on x86Sim", TextAlignment = UITextAlignment.Center },
			label,
			button,
		}) {
			Axis = UILayoutConstraintAxis.Vertical,
			Spacing = 12,
			TranslatesAutoresizingMaskIntoConstraints = false,
		};
		var vc = new UIViewController ();
		vc.View!.BackgroundColor = UIColor.SystemBackground;
		vc.View.AddSubview (stack);
		NSLayoutConstraint.ActivateConstraints (new [] {
			stack.CenterXAnchor.ConstraintEqualTo (vc.View.CenterXAnchor),
			stack.CenterYAnchor.ConstraintEqualTo (vc.View.CenterYAnchor),
		});

		Window.RootViewController = vc;
		Window.MakeKeyAndVisible ();
	}
}
