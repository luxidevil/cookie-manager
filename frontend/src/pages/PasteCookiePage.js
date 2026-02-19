import { useState } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios";
import { useAuth } from "@/context/AuthContext";
import Layout from "@/components/Layout";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { CheckCircle, XCircle, Save, Loader2 } from "lucide-react";
import { toast } from "sonner";

const API = `${process.env.REACT_APP_BACKEND_URL}/api`;

export default function PasteCookiePage() {
  const [content, setContent] = useState("");
  const [validationResult, setValidationResult] = useState(null);
  const [isValidating, setIsValidating] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const { getAuthHeaders } = useAuth();
  const navigate = useNavigate();

  const handleValidate = async () => {
    if (!content.trim()) {
      toast.error("Please paste cookie content first");
      return;
    }

    setIsValidating(true);
    try {
      const response = await axios.post(
        `${API}/cookies/validate`,
        { content },
        { headers: getAuthHeaders() }
      );
      setValidationResult(response.data);
      if (response.data.valid) {
        toast.success("Cookie JSON is valid!");
      }
    } catch (error) {
      setValidationResult({
        valid: false,
        message: error.response?.data?.detail || "Validation failed",
      });
    } finally {
      setIsValidating(false);
    }
  };

  const handleSave = async () => {
    if (!validationResult?.valid) {
      toast.error("Please validate the cookie first");
      return;
    }

    setIsSaving(true);
    try {
      await axios.post(
        `${API}/cookies`,
        { content },
        { headers: getAuthHeaders() }
      );
      toast.success("Cookie saved successfully!");
      setContent("");
      setValidationResult(null);
      navigate("/cookies");
    } catch (error) {
      toast.error(error.response?.data?.detail || "Failed to save cookie");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Layout>
      <div className="max-w-4xl mx-auto space-y-6">
        <div>
          <h1 className="text-3xl font-semibold tracking-tight">Paste Cookie</h1>
          <p className="text-muted-foreground mt-1">
            Paste your cookie JSON content below. The format will be validated automatically.
          </p>
        </div>

        <div className="space-y-4">
          <div className="relative">
            <Textarea
              placeholder='Paste your cookie JSON here...\n\nExample:\n[\n  {\n    "name": "session",\n    "value": "abc123",\n    "domain": ".example.com"\n  }\n]'
              value={content}
              onChange={(e) => {
                setContent(e.target.value);
                setValidationResult(null);
              }}
              className="notepad-textarea min-h-[400px] bg-muted/30 border-border resize-none"
              data-testid="cookie-textarea"
            />
          </div>

          {validationResult && (
            <Alert
              className={`animate-in ${
                validationResult.valid
                  ? "border-green-500 bg-green-50 text-green-800"
                  : "border-destructive bg-red-50 text-red-800"
              }`}
              data-testid="validation-alert"
            >
              {validationResult.valid ? (
                <CheckCircle className="w-4 h-4 text-green-600" />
              ) : (
                <XCircle className="w-4 h-4 text-red-600" />
              )}
              <AlertDescription className="ml-2">
                {validationResult.message}
              </AlertDescription>
            </Alert>
          )}

          {validationResult?.valid && validationResult.formatted_content && (
            <div className="space-y-2">
              <p className="text-sm font-medium text-muted-foreground">
                Formatted Preview:
              </p>
              <pre
                className="notepad-textarea bg-muted/50 p-4 rounded-md border text-xs overflow-auto max-h-64"
                data-testid="formatted-preview"
              >
                {validationResult.formatted_content}
              </pre>
            </div>
          )}

          <div className="flex gap-3">
            <Button
              onClick={handleValidate}
              disabled={isValidating || !content.trim()}
              variant="outline"
              className="btn-active transition-smooth"
              data-testid="validate-button"
            >
              {isValidating ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Validating...
                </>
              ) : (
                "Validate"
              )}
            </Button>
            <Button
              onClick={handleSave}
              disabled={!validationResult?.valid || isSaving}
              className="btn-active transition-smooth"
              data-testid="save-button"
            >
              {isSaving ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4 mr-2" />
                  Save Cookie
                </>
              )}
            </Button>
          </div>
        </div>
      </div>
    </Layout>
  );
}
