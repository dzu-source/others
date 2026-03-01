import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext
import numpy as np
from sklearn.neural_network import MLPRegressor
import re
import os

class NumberPredictorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Number Sequence Predictor")
        self.root.geometry("600x500")

        self.numbers = []
        self.model = None
        self.window_size = 5 # How many previous numbers to look at

        self.setup_ui()

    def setup_ui(self):
        # File Selection Frame
        file_frame = tk.Frame(self.root)
        file_frame.pack(pady=10, padx=10, fill=tk.X)

        self.btn_load = tk.Button(file_frame, text="Load Text File", command=self.load_file)
        self.btn_load.pack(side=tk.LEFT, padx=5)

        self.lbl_file = tk.Label(file_frame, text="No file selected")
        self.lbl_file.pack(side=tk.LEFT, padx=5)

        # Data Display Frame
        data_frame = tk.Frame(self.root)
        data_frame.pack(pady=10, padx=10, fill=tk.BOTH, expand=True)

        tk.Label(data_frame, text="Extracted Numbers:").pack(anchor=tk.W)
        self.txt_data = scrolledtext.ScrolledText(data_frame, height=8)
        self.txt_data.pack(fill=tk.BOTH, expand=True)
        self.txt_data.config(state=tk.DISABLED)

        # Training Frame
        train_frame = tk.Frame(self.root)
        train_frame.pack(pady=10, padx=10, fill=tk.X)

        tk.Label(train_frame, text="Window Size (Features):").pack(side=tk.LEFT)
        self.entry_window = tk.Entry(train_frame, width=5)
        self.entry_window.insert(0, "5")
        self.entry_window.pack(side=tk.LEFT, padx=5)

        self.btn_train = tk.Button(train_frame, text="Train Model", command=self.train_model, state=tk.DISABLED)
        self.btn_train.pack(side=tk.LEFT, padx=20)

        self.lbl_status = tk.Label(train_frame, text="Status: Waiting for data...", fg="blue")
        self.lbl_status.pack(side=tk.LEFT, padx=5)

        # Prediction Frame
        pred_frame = tk.Frame(self.root)
        pred_frame.pack(pady=10, padx=10, fill=tk.X)

        self.btn_predict = tk.Button(pred_frame, text="Predict Next Number", command=self.predict_next, state=tk.DISABLED)
        self.btn_predict.pack(side=tk.LEFT, padx=5)

        self.lbl_prediction = tk.Label(pred_frame, text="Prediction: ---", font=("Arial", 14, "bold"))
        self.lbl_prediction.pack(side=tk.LEFT, padx=20)

    def load_file(self):
        filepath = filedialog.askopenfilename(
            filetypes=[("Text Files", "*.txt"), ("All Files", "*.*")]
        )
        if not filepath:
            return

        self.lbl_file.config(text=os.path.basename(filepath))

        try:
            with open(filepath, 'r') as file:
                content = file.read()

            # Extract numbers using regex (handles ints and floats)
            # Find all numbers, including optional negative signs and decimals
            number_strings = re.findall(r'-?\d+(?:\.\d+)?', content)

            self.numbers = [float(num) for num in number_strings]

            self.txt_data.config(state=tk.NORMAL)
            self.txt_data.delete(1.0, tk.END)
            self.txt_data.insert(tk.END, str(self.numbers))
            self.txt_data.config(state=tk.DISABLED)

            if len(self.numbers) > 1:
                self.btn_train.config(state=tk.NORMAL)
                self.lbl_status.config(text=f"Loaded {len(self.numbers)} numbers. Ready to train.")
            else:
                self.btn_train.config(state=tk.DISABLED)
                self.lbl_status.config(text="Error: Need at least 2 numbers.", fg="red")
                messagebox.showerror("Data Error", "The file must contain at least 2 numbers.")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to read file:\n{str(e)}")

    def prepare_data(self):
        try:
            self.window_size = int(self.entry_window.get())
            if self.window_size < 1:
                raise ValueError("Window size must be at least 1.")
        except ValueError:
            messagebox.showerror("Input Error", "Invalid window size.")
            return None, None

        if len(self.numbers) <= self.window_size:
            messagebox.showerror("Data Error", f"Not enough data. Need more than {self.window_size} numbers for a window size of {self.window_size}.")
            return None, None

        X = []
        y = []
        for i in range(len(self.numbers) - self.window_size):
            X.append(self.numbers[i : i + self.window_size])
            y.append(self.numbers[i + self.window_size])

        return np.array(X), np.array(y)

    def train_model(self):
        X, y = self.prepare_data()
        if X is None or y is None:
            return

        self.lbl_status.config(text="Training model...", fg="orange")
        self.root.update()

        try:
            # Using a simple Multi-Layer Perceptron
            # For small datasets, early_stopping might fail if validation set size is 0,
            # so we only enable it if we have enough data
            use_early_stopping = len(X) > 10

            self.model = MLPRegressor(
                hidden_layer_sizes=(50, 50),
                max_iter=2000,
                random_state=42,
                early_stopping=use_early_stopping
            )
            self.model.fit(X, y)

            score = self.model.score(X, y) # R^2 score on training data

            self.lbl_status.config(text=f"Training complete (R^2: {score:.2f})", fg="green")
            self.btn_predict.config(state=tk.NORMAL)

        except Exception as e:
            self.lbl_status.config(text="Training failed.", fg="red")
            messagebox.showerror("Training Error", f"An error occurred during training:\n{str(e)}")

    def predict_next(self):
        if not self.model or len(self.numbers) < self.window_size:
            return

        # Take the last 'window_size' numbers to predict the next one
        last_window = np.array(self.numbers[-self.window_size:]).reshape(1, -1)

        try:
            prediction = self.model.predict(last_window)[0]
            self.lbl_prediction.config(text=f"Prediction: {prediction:.4f}")
        except Exception as e:
            messagebox.showerror("Prediction Error", f"An error occurred:\n{str(e)}")


def headless_test():
    # Helper for testing without GUI
    print("Running headless test...", flush=True)

    root = tk.Tk()
    app = NumberPredictorApp(root)
    # Create dummy data
    with open("dummy_test.txt", "w") as f:
        f.write("10 20 30 40 50 60 70 80 90 100")

    app.numbers = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
    X, y = app.prepare_data()
    print(f"Data prepared. X shape: {X.shape}, y shape: {y.shape}", flush=True)
    app.train_model()
    print("Model trained.", flush=True)

    # Manually test prediction logic
    last_window = np.array(app.numbers[-app.window_size:]).reshape(1, -1)
    pred = app.model.predict(last_window)[0]
    print(f"Prediction for next number after 100: {pred}", flush=True)
    print("Headless test complete.", flush=True)

    # Keep the output so tests pass, remove manual sys.exit and let test finish normally
    root.destroy()

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == '--test':
        headless_test()
    else:
        root = tk.Tk()
        app = NumberPredictorApp(root)
        root.mainloop()
