import { useState, useEffect } from "react";
import axios from "axios";
import { useAuth } from "@/context/AuthContext";
import Layout from "@/components/Layout";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Copy, Link, RefreshCw, Loader2, Check } from "lucide-react";
import { toast } from "sonner";

const API = `${process.env.REACT_APP_BACKEND_URL}/api`;

export default function AllCookiesPage() {
  const [cookies, setCookies] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState(null);
  const [generatedLinks, setGeneratedLinks] = useState({});
  const [copiedLinkId, setCopiedLinkId] = useState(null);
  const { getAuthHeaders } = useAuth();

  const fetchCookies = async () => {
    try {
      const response = await axios.get(`${API}/cookies`, {
        headers: getAuthHeaders(),
      });
      setCookies(response.data);
    } catch (error) {
      toast.error("Failed to load cookies");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCookies();
  }, []);

  const handleCopy = async (cookie) => {
    try {
      await navigator.clipboard.writeText(cookie.content);
      toast.success(`${cookie.name} copied to clipboard`);
    } catch (error) {
      toast.error("Failed to copy");
    }
  };

  const handleStatusChange = async (cookieId, field, value) => {
    setUpdatingId(cookieId);
    try {
      const response = await axios.patch(
        `${API}/cookies/${cookieId}`,
        { [field]: value },
        { headers: getAuthHeaders() }
      );
      setCookies((prev) =>
        prev.map((c) => (c.id === cookieId ? response.data : c))
      );
      toast.success(`Status updated`);
    } catch (error) {
      toast.error("Failed to update status");
    } finally {
      setUpdatingId(null);
    }
  };

  const handleGetLink = async (cookieId) => {
    setUpdatingId(cookieId);
    try {
      // TODO: Replace with actual RDP call later
      // For now, generate a mock link
      const mockLink = `https://example.com/cookie/${cookieId.substring(0, 8)}`;
      
      setGeneratedLinks((prev) => ({
        ...prev,
        [cookieId]: mockLink,
      }));
      
      const response = await axios.patch(
        `${API}/cookies/${cookieId}`,
        { link_generated: true },
        { headers: getAuthHeaders() }
      );
      setCookies((prev) =>
        prev.map((c) => (c.id === cookieId ? response.data : c))
      );
      toast.success("Link generated");
    } catch (error) {
      toast.error("Failed to generate link");
    } finally {
      setUpdatingId(null);
    }
  };

  const handleCopyLink = async (cookieId, link) => {
    try {
      await navigator.clipboard.writeText(link);
      setCopiedLinkId(cookieId);
      toast.success("Link copied to clipboard");
      setTimeout(() => setCopiedLinkId(null), 2000);
    } catch (error) {
      toast.error("Failed to copy link");
    }
  };

  if (isLoading) {
    return (
      <Layout>
        <div className="flex items-center justify-center h-64">
          <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-semibold tracking-tight">All Cookies</h1>
            <p className="text-muted-foreground mt-1">
              Manage your saved cookies
            </p>
          </div>
          <Button
            variant="outline"
            onClick={fetchCookies}
            className="btn-active"
            data-testid="refresh-button"
          >
            <RefreshCw className="w-4 h-4 mr-2" />
            Refresh
          </Button>
        </div>

        {cookies.length === 0 ? (
          <div
            className="text-center py-16 text-muted-foreground"
            data-testid="empty-state"
          >
            No cookies saved yet. Go to Paste Cookie to add one.
          </div>
        ) : (
          <div className="border rounded-lg overflow-hidden">
            <Table>
              <TableHeader>
                <TableRow className="bg-muted/50">
                  <TableHead className="font-semibold">Cookie</TableHead>
                  <TableHead className="font-semibold text-center w-24">
                    Sold
                  </TableHead>
                  <TableHead className="font-semibold text-center w-24">
                    Expired
                  </TableHead>
                  <TableHead className="font-semibold text-center w-40">
                    Actions
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {cookies.map((cookie) => (
                  <TableRow
                    key={cookie.id}
                    className="hover:bg-muted/30 transition-colors cursor-pointer"
                    data-testid={`cookie-row-${cookie.id}`}
                  >
                    <TableCell
                      className="font-medium"
                      onClick={() => handleCopy(cookie)}
                      data-testid={`cookie-name-${cookie.id}`}
                    >
                      <div className="flex items-center gap-2">
                        <span>{cookie.name}</span>
                        <Copy className="w-3.5 h-3.5 text-muted-foreground opacity-0 group-hover:opacity-100" />
                      </div>
                      <p className="text-xs text-muted-foreground font-mono truncate max-w-xs mt-1">
                        {cookie.content.substring(0, 50)}...
                      </p>
                    </TableCell>
                    <TableCell className="text-center">
                      <Checkbox
                        checked={cookie.sold}
                        onCheckedChange={(checked) =>
                          handleStatusChange(cookie.id, "sold", checked)
                        }
                        disabled={updatingId === cookie.id}
                        data-testid={`sold-checkbox-${cookie.id}`}
                      />
                    </TableCell>
                    <TableCell className="text-center">
                      <Checkbox
                        checked={cookie.expired}
                        onCheckedChange={(checked) =>
                          handleStatusChange(cookie.id, "expired", checked)
                        }
                        disabled={updatingId === cookie.id}
                        data-testid={`expired-checkbox-${cookie.id}`}
                      />
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-col gap-2">
                        <div className="flex items-center gap-2">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleCopy(cookie)}
                            className="btn-active"
                            data-testid={`copy-button-${cookie.id}`}
                          >
                            <Copy className="w-4 h-4" />
                          </Button>
                          {cookie.link_generated && generatedLinks[cookie.id] ? (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleGetLink(cookie.id)}
                              disabled={updatingId === cookie.id}
                              className="btn-active text-xs"
                              data-testid={`regenerate-link-${cookie.id}`}
                            >
                              <RefreshCw className="w-3.5 h-3.5 mr-1" />
                              Generate Again
                            </Button>
                          ) : (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleGetLink(cookie.id)}
                              disabled={updatingId === cookie.id}
                              className="btn-active text-xs"
                              data-testid={`get-link-${cookie.id}`}
                            >
                              {updatingId === cookie.id ? (
                                <Loader2 className="w-3.5 h-3.5 mr-1 animate-spin" />
                              ) : (
                                <Link className="w-3.5 h-3.5 mr-1" />
                              )}
                              Get Link
                            </Button>
                          )}
                        </div>
                        {generatedLinks[cookie.id] && (
                          <div className="flex items-center gap-2 mt-1">
                            <Input
                              value={generatedLinks[cookie.id]}
                              readOnly
                              className="h-8 text-xs font-mono bg-muted/50 flex-1"
                              data-testid={`link-input-${cookie.id}`}
                            />
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleCopyLink(cookie.id, generatedLinks[cookie.id])}
                              className="btn-active h-8 px-2"
                              data-testid={`copy-link-${cookie.id}`}
                            >
                              {copiedLinkId === cookie.id ? (
                                <Check className="w-4 h-4 text-green-600" />
                              ) : (
                                <Copy className="w-4 h-4" />
                              )}
                            </Button>
                          </div>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </div>
    </Layout>
  );
}
